import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:petit/common/domain/media_exception.dart';
import 'package:petit/core/utils/work_dir.dart';
import 'package:petit/features/videos/domain/entities/video_data.dart';
import 'package:petit/features/videos/domain/services/video_compressor.dart';

class FfmpegVideoCompressor implements VideoCompressor {
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

      return VideoData(
        videoFile: video,
        pixelWidth: videoStream.getWidth(),
        pixelHeight: videoStream.getHeight(),
        videoCodec: videoStream.getCodec(),
        frameRate: frameRate,
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
  }) async {
    final jobDir = await createJobDir();
    final outPath = p.join(
        jobDir.path, 'compressed_${DateTime.now().millisecondsSinceEpoch}.mp4');

    // Passed as a list (not one string) so paths with spaces work on every OS.
    final arguments = <String>[
      '-i',
      input.path,
      '-vcodec',
      videoCodec,
      '-crf',
      '$crf',
      '-preset',
      preset,
      outPath,
    ];

    final completer = Completer<File>();

    final session = await FFmpegKit.executeWithArgumentsAsync(
      arguments,
      (session) async {
        final returnCode = await session.getReturnCode();
        if (ReturnCode.isSuccess(returnCode)) {
          completer.complete(File(outPath));
        } else {
          completer.completeError(const MediaException('Compression failed.'));
        }
      },
      (log) => debugPrint('FFmpeg log: ${log.getMessage()}'),
      (statistics) {
        final progress = statistics.getTime();
        final percent = (progress / totalDurationMs * 100).clamp(0, 100).toInt();
        onProgress(percent);
      },
    );

    return _FfmpegTask(session, completer.future);
  }
}

class _FfmpegTask implements VideoCompressionTask {
  _FfmpegTask(this._session, this.result);

  final FFmpegSession _session;

  @override
  final Future<File> result;

  @override
  Future<void> cancel() async {
    await _session.cancel();
  }
}
