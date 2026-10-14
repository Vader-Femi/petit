import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:petit/common/domain/media_exception.dart';
import 'package:petit/core/utils/platform_utils.dart';
import 'package:petit/core/utils/work_dir.dart';
import 'package:petit/features/videos/data/services/ffmpeg_arguments.dart';
import 'package:petit/features/videos/data/services/hardware_encoders.dart';
import 'package:petit/features/videos/domain/entities/video_data.dart';
import 'package:petit/features/videos/domain/services/video_compressor.dart';

class FfmpegVideoCompressor implements VideoCompressor {
  /// Hardware encoder found for each software codec (null: none works). The
  /// probe runs once per codec per app run.
  final Map<String, String?> _hardwareEncoders = {};

  @override
  Future<String?> hardwareEncoderFor(String videoCodec) async {
    if (_hardwareEncoders.containsKey(videoCodec)) {
      return _hardwareEncoders[videoCodec];
    }

    String? found;
    for (final encoder
        in hardwareEncoderCandidates(videoCodec, PlatformInfo.osName)) {
      try {
        final session = await FFmpegKit.executeWithArguments(
            buildHardwareProbeArguments(encoder));
        if (ReturnCode.isSuccess(await session.getReturnCode())) {
          found = encoder;
          break;
        }
      } catch (e) {
        debugPrint('Hardware encoder $encoder is not usable: $e');
      }
    }

    return _hardwareEncoders[videoCodec] = found;
  }
  @override
  Future<VideoData> probe(File video) async {
    try {
      final session = await FFprobeKit.getMediaInformation(video.path);
      final info = session.getMediaInformation();

      if (info == null) {
        throw const MediaException('Could not retrieve media information.');
      }

      final videoStreams =
          info.getStreams().where((s) => s.getType() == 'video');
      final videoStream = videoStreams.first;

      String? frameRateStr = videoStream.getAverageFrameRate();
      List<String>? parts = frameRateStr?.split('/');

      int? frameRate;
      if (parts != null && parts.length == 2) {
        double numerator = double.tryParse(parts[0]) ?? 0;
        double denominator = double.tryParse(parts[1]) ?? 1;
        frameRate = (numerator / denominator).round();
      }

      // Format duration is a string of seconds, e.g. "12.345000".
      final seconds = double.tryParse(info.getDuration() ?? '');

      return VideoData(
        videoFile: video,
        pixelWidth: videoStream.getWidth(),
        pixelHeight: videoStream.getHeight(),
        videoCodec: videoStream.getCodec(),
        frameRate: frameRate,
        durationMs: seconds == null ? null : (seconds * 1000).round(),
      );
    } on MediaException catch (e) {
      debugPrint('Video probe failed: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Video probe failed: $e');
      throw MediaException('Error retrieving media information: $e');
    }
  }

  @override
  Future<VideoCompressionTask> start({
    required File input,
    required String videoCodec,
    required int crf,
    required String preset,
    required int totalDurationMs,
    required void Function(int percent) onProgress,
    int? videoBitrateKbps,
    int? maxShortSide,
    String? hardwareEncoder,
    int? hardwareBitrateKbps,
  }) async {
    final jobDir = await createJobDir();
    // The job folder is unique, so the name can simply follow the original's.
    final outPath = p.join(
        jobDir.path, '${p.basenameWithoutExtension(input.path)}_compressed.mp4');

    final softwareArguments = buildVideoArguments(
      inputPath: input.path,
      outputPath: outPath,
      videoCodec: videoCodec,
      crf: crf,
      preset: preset,
      videoBitrateKbps: videoBitrateKbps,
      maxShortSide: maxShortSide,
    );

    final useHardware = hardwareEncoder != null && hardwareBitrateKbps != null;
    final firstArguments = useHardware
        ? buildVideoArguments(
            inputPath: input.path,
            outputPath: outPath,
            videoCodec: videoCodec,
            crf: crf,
            preset: preset,
            videoBitrateKbps: hardwareBitrateKbps,
            maxShortSide: maxShortSide,
            hardwareEncoder: hardwareEncoder,
          )
        : softwareArguments;

    final task = _FfmpegTask();

    Future<void> run(List<String> arguments, {required bool canFallBack}) async {
      task.session = await FFmpegKit.executeWithArgumentsAsync(
        arguments,
        (session) async {
          final returnCode = await session.getReturnCode();
          if (ReturnCode.isSuccess(returnCode)) {
            task.complete(File(outPath));
          } else if (canFallBack &&
              !task.cancelled &&
              !ReturnCode.isCancel(returnCode)) {
            // The hardware could not do it (driver, format, size): do it the
            // normal way instead. The half-written file would be refused by
            // FFmpeg, so it goes first.
            debugPrint('Hardware encoding failed; using software encoding.');
            try {
              final partial = File(outPath);
              if (await partial.exists()) await partial.delete();
            } on FileSystemException {
              // FFmpeg will report it if this matters.
            }
            onProgress(0);
            await run(softwareArguments, canFallBack: false);
          } else {
            task.fail(const MediaException('Compression failed.'));
          }
        },
        (log) => debugPrint('FFmpeg log: ${log.getMessage()}'),
        (statistics) {
          final progress = statistics.getTime();
          final percent =
              (progress / totalDurationMs * 100).clamp(0, 100).toInt();
          onProgress(percent);
        },
      );
    }

    await run(firstArguments, canFallBack: useHardware);

    return task;
  }
}

/// The running compression. It can swap its FFmpeg session for another one
/// (the software retry), so cancelling always reaches the one that is running.
class _FfmpegTask implements VideoCompressionTask {
  final _completer = Completer<File>();
  FFmpegSession? session;
  bool cancelled = false;

  @override
  Future<File> get result => _completer.future;

  void complete(File file) {
    if (!_completer.isCompleted) _completer.complete(file);
  }

  void fail(MediaException error) {
    if (!_completer.isCompleted) _completer.completeError(error);
  }

  @override
  Future<void> cancel() async {
    cancelled = true;
    await session?.cancel();
  }
}
