import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_super/flutter_super.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'dart:io'; // Still needed for File type, XFile uses it.
// import 'dart:html' as html; // Web specific
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:petit/common/data/summary_report.dart';
import 'package:petit/features/videos/data/slider_value.dart';
import 'package:petit/features/videos/data/video_data.dart';
import 'package:share_handler/share_handler.dart'; // Assuming this has web support or is handled
import 'package:video_player/video_player.dart';
import '../../data/codec_config.dart';

// IMPORTANT: This getVideosViewModel will be shadowed by the one in videos_page.dart
// due to conditional import. Ensure the instance used is the web one when on web.
// It might be better if the page directly instantiates or Super.init() the correct version.
// For now, keeping the structure, but this is a potential refactor point if Super.init
// doesn't play well with conditional imports for the *same* class name.
// A common pattern is to have a base class and platform-specific implementations.
// Or, the page itself does Super.init(kIsWeb ? VideosViewModelWeb() : VideosViewModelMobile())
// if class names were different.
VideosViewModelWeb get getVideosViewModelWeb => Super.init(VideosViewModelWeb());


class VideosViewModelWeb {
  final result = RxT<String?>(null);
  final isLoading = RxBool(false);
  final videoFile = RxT<File?>(null); // image_picker on web returns XFile, XFile.path is blob url, File(blob_url) is used by video_player
  final videoController = RxT<VideoPlayerController?>(null);
  final isCompressing = RxBool(false);
  final cfrQualitySlider = RxInt(80);
  final percentageComplete = RxInt(0);
  final selectedPresetIndex = RxInt(1);
  final isFabOpen = RxT<bool>(true);
  final currentSession = RxT<FFmpegSession?>(null);

  List<SliderValue> ffmpegPresets = [
    SliderValue(value: "fast", desc: "Best Quality"),
    SliderValue(value: "medium", desc: "Balanced File"),
    SliderValue(value: "slow", desc: "Smallest File"),
  ];

  String getLabelForCRFSlider(int value) {
    if (value <= 20) return "Minimal";
    if (value <= 40) return "Very Light";
    if (value <= 60) return "Light";
    if (value <= 80) return "Moderate";
    return "Heavy";
  }

  void setIsLoading(bool isLoading) {
    this.isLoading.state = isLoading;
  }

  void setIsCompressing(bool isCompressing) {
    this.isCompressing.state = isCompressing;
  }

  void setPercentageComplete(int value) {
    percentageComplete.state = value;
  }

  void setPresetIndex(int index) {
    selectedPresetIndex.state = index;
  }

  Future<void> showResult(String? result) async {
    this.result.state = result;
  }

  void updateCfrQualitySlider(double value) {
    cfrQualitySlider.state = (value * 100).toInt();
  }

  Future<void> pickVideo() async {
    if (isCompressing.state) return;
    try {
      setIsLoading(true);
      final pickedXFile = await ImagePicker().pickVideo(source: ImageSource.gallery);

      if (pickedXFile != null) {
        // On web, XFile.path is a blob URL. VideoPlayerController.file can handle this.
        final file = File(pickedXFile.path);
        videoController.state = VideoPlayerController.file(file);
        await videoController.state?.initialize();
        videoFile.state = file; // Store the File object
        setIsLoading(false);
      } else {
        await showResult("No file picked!");
        setIsLoading(false);
      }
    } catch (e) {
      await showResult("An error occurred - ${e.toString()}");
      setIsLoading(false);
    }
  }

  Future<SummaryReport?> compressVideo({
    required Function(SummaryReport summaryReport) onComplete,
  }) async {
    try {
      currentSession.state?.cancel();
      currentSession.state = null;
      if (videoFile.state == null) return null;

      // videoFile.state.path is critical here. For web, it's a blob URL.
      // FFmpegKit (WASM) needs to support blob URLs as input.
      final originalFile = videoFile.state!;
      setIsCompressing(true);
      percentageComplete.state = 0;

      // getVideoData also relies on originalFile.path
      final data = await getVideoData(originalFile);
      if (data == null ||
          data.frameRate == null ||
          data.pixelHeight == null ||
          data.pixelWidth == null ||
          data.videoCodec == null) {
        await showResult('Error retrieving video properties');
        setIsCompressing(false);
        return null;
      }

      // path_provider's getTemporaryDirectory() on web provides a virtual filesystem path.
      // FFmpegKit (WASM) needs to be able to write to this.
      final outputDir = await getTemporaryDirectory();
      final outPath = '${outputDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.mp4';

      final codecConfig = getVcodecConfigFromCodec(data.videoCodec!);
      final crf = (codecConfig.minCrf + ((cfrQualitySlider.state / 100) * (codecConfig.maxCrf - codecConfig.minCrf))).round();
      final selectedPreset = ffmpegPresets[selectedPresetIndex.state].value;

      final command = "-i ${originalFile.path} -vcodec ${codecConfig.vcodec} -crf $crf -preset $selectedPreset $outPath";

      debugPrint("FFmpeg command for web: $command");

      currentSession.state = await FFmpegKit.executeAsync(
        command,
            (session) async {
          final returnCode = await session.getReturnCode();
          if (ReturnCode.isSuccess(returnCode)) {
            final compressedFileFromPath = File(outPath); // This File object points to the virtual path

            // To download, we need bytes. Read from the virtual path.
            // This assumes FFmpegKit wrote the file correctly and it can be read back.
            // final Uint8List compressedBytes = await compressedFileFromPath.readAsBytes();

            // originalFile.length() will attempt to get length of blob URL, which might work.
            // For compressedFile, we need its actual length after compression.
            // This might require reading the file if File(outPath).length() doesn't work on virtual fs.
            final sizeBefore = await originalFile.length();
            var sizeAfter = await compressedFileFromPath.length(); // Potentially problematic on virtual fs

            // For web, we don't compare sizes to return original, we always provide the compressed one for download.
            // Or, if FFmpeg fails to make it smaller, the user gets the larger file.
            // For simplicity, we assume compressedFile is what we want to provide.

            final saved = sizeBefore - sizeAfter;
            final savedPercent = (saved > 0 && sizeBefore > 0) ? (saved / sizeBefore).clamp(0, 1).toDouble() : 0.0;

            // Pass the File object (pointing to virtual path) to saveLocalVideo
            await saveLocalVideo(compressedFileFromPath, outPath.split('/').last);
            removeVideo();
            await clearCacheDir(); // Web version of clearCacheDir

            setIsCompressing(false);
            setIsLoading(false);

            final summary = SummaryReport(
              originalSizeBytes: formatBytes(sizeBefore),
              compressedSizeBytes: formatBytes(sizeAfter),
              savedBytes: formatBytes(saved),
              savedPercent: savedPercent,
              path: "Downloads", // Web path
            );
            onComplete(summary);
          } else {
            final logs = await session.getAllLogsAsString();
            debugPrint("FFmpeg failed. Logs: $logs");
            await showResult('Compression failed. RC: ${await session.getReturnCode()}');
            setIsCompressing(false);
            setIsLoading(false);
          }
        },
            (log) => debugPrint('FFmpeg log (web): ${log.getMessage()}'),
            (statistics) {
          final progress = statistics.getTime();
          if (videoController.state?.value.isInitialized ?? false) {
            final duration = videoController.state!.value.duration.inMilliseconds;
            if (duration > 0) {
              final percent = (progress / duration * 100).clamp(0, 100).toInt();
              percentageComplete.state = percent;
            }
          }
        },
      );
    } catch (e) {
      await showResult('Error compressing video: $e');
      setIsCompressing(false);
      setIsLoading(false);
    }
    return null;
  }

  Future<VideoData?> getVideoData(File videoFile) async {
    // FFprobeKit.getMediaInformation needs to work with blob URL (videoFile.path) on web
    try {
      final session = await FFprobeKit.getMediaInformation(videoFile.path);
      final info = session.getMediaInformation();
      if (info != null) {
        final videoStreams = info.getStreams().where((s) => s.getType() == 'video');
        if (videoStreams.isEmpty) {
          showResult('No video stream found in the file.');
          return null;
        }
        final videoStream = videoStreams.first;
        String? frameRateStr = videoStream.getAverageFrameRate();
        List<String>? parts = frameRateStr?.split('/');
        int? frameRate;
        if (parts != null && parts.length == 2) {
          double numerator = double.tryParse(parts[0]) ?? 0;
          double denominator = double.tryParse(parts[1]) ?? 1;
          if (denominator != 0) {
            frameRate = (numerator / denominator).round();
          }
        }
        return VideoData(
            videoFile: videoFile,
            pixelWidth: videoStream.getWidth(),
            pixelHeight: videoStream.getHeight(),
            videoCodec: videoStream.getCodec(),
            frameRate: frameRate);
      } else {
        showResult('Could not retrieve media information.');
      }
    } catch (e) {
      showResult('Error retrieving media information: $e');
    }
    return null;
  }

  // Web specific save using dart:html
  // Future<void> saveLocalVideo(File fileToSave, String downloadFileName) async {
  //   try {
  //     // Read bytes from the File object (which might be from a virtual path from path_provider)
  //     final Uint8List bytes = await fileToSave.readAsBytes();
  //     final blob = html.Blob([bytes]);
  //     final url = html.Url.createObjectUrlFromBlob(blob);
  //     final anchor = html.AnchorElement(href: url)
  //       ..setAttribute("download", downloadFileName)
  //       ..click();
  //     html.Url.revokeObjectUrl(url);
  //     await showResult("Video saved to Downloads.");
  //   } catch (e) {
  //     await showResult("Error occurred while saving - ${e.toString()}");
  //   }
  // }

  Future<void> saveLocalVideo(File fileToSave, String downloadFileName) async {
    try {
      // Save the file directly to the gallery
      final saved = await GallerySaver.saveImage(fileToSave.path);
      if (saved == true) {
        await showResult("Image saved to gallery.");
      } else {
        await showResult("Failed to save image.");
      }
    } catch (e) {
      await showResult("Error occurred while saving - ${e.toString()}");
    }
  }

  String formatBytes(int bytes, [int decimals = 2]) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB"];
    final i = (bytes == 0) ? 0 : (bytes.bitLength / 10).floor();
    final size = bytes / (1 << (10 * i));
    return '${size.toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  // Web specific clearCacheDir (likely a no-op or minimal)
  Future<void> clearCacheDir() async {
    debugPrint("clearCacheDir (web): Called. Typically a no-op or clears specific plugin caches if possible.");
    // If ffmpeg_kit or other plugins create specific temp files via path_provider on web,
    // and if those files are identifiable, they could be cleared here.
    // For now, it's a no-op.
    // Example: final tempDir = await getTemporaryDirectory(); then iterate and delete.
    // But be cautious with virtual file systems.
  }

  void removeVideo() {
    videoController.state?.dispose();
    videoController.state = null;
    videoFile.state = null;
    isCompressing.state = false;
    isLoading.state = false;
    percentageComplete.state = 0;
  }

  void cancelCompressingVideo() {
    if (currentSession.state != null) {
      currentSession.state!.cancel();
      currentSession.state = null; // Important to nullify after cancel
      setIsCompressing(false);
      setIsLoading(false);
      setPercentageComplete(0);
      showResult("Compression cancelled.");
    } else {
      debugPrint("⚠️ Tried to cancel but session was null");
    }
  }
}
