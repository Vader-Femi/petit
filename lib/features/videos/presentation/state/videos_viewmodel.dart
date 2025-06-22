import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_super/flutter_super.dart';
import 'dart:io';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:petit/common/data/Summary_report.dart';
import 'package:petit/features/videos/data/video_data.dart';
import 'package:video_player/video_player.dart';

// import 'package:receive_sharing_intent/receive_sharing_intent.dart';

VideosViewModel get getVideosViewModel => Super.init(VideosViewModel());

class VideosViewModel {
  final result = RxT<String?>(null);
  final isLoading = RxBool(false);
  final videoFile = RxT<File?>(null);
  final videoController = RxT<VideoPlayerController?>(null);
  final isCompressing = RxBool(false);
  final globalQualitySlider = RxInt(75);
  final isFabOpen = RxT<bool>(true);
  final percentageComplete = RxInt(0);
  final selectedPresetIndex = RxInt(6);

  Session? _currentSession;
  List<String> ffmpegPresets = [
    'ultrafast',
    'superfast',
    'veryfast',
    'faster',
    'fast',
    'medium', // 🟢 good default
    'slow',
    'slower',
    'veryslow',
  ];

  String get selectedPreset => ffmpegPresets[selectedPresetIndex.state];

  String getLabelForSlider(int value) {
    switch (value) {
      case 0:
        return "Compressed";
      case 25:
        return "Low";
      case 50:
        return "Medium";
      case 75:
        return "High";
      case 100:
        return "Ultra";
      default:
        return "";
    }
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

  // void setPreset(String newPreset) {
  //   selectedPreset = newPreset;
  // }

  Future<void> showResult(String? result) async {
    this.result.state = result;
  }

  void updateGlobalQualitySlider(double value) {
    globalQualitySlider.state = (value * 100).toInt();
  }

  Future<void> pickVideo() async {
    if (isCompressing.state) return;
    try {
      setIsLoading(true);

      final result = await ImagePicker().pickVideo(source: ImageSource.gallery);

      if (result != null) {
        final file = File(result.path);
        videoController.state = VideoPlayerController.file(file);
        await videoController.state?.initialize();
        videoFile.state = file;


        setIsLoading(false);
      } else {
        await showResult("No file picked!");
        setIsLoading(false);
      }
    } catch (e) {
      await showResult("An error ocurred - ${e.toString()}");
      setIsLoading(false);
    }
  }

  Future<void> addSharedImages(// List<SharedMediaFile>? sharedFiles
      ) async {
    // if (sharedFiles != null && sharedFiles.isNotEmpty) {
    //
    //   setIsLoading(
    //     LoadingData(
    //         isLoading: true,
    //         completedSteps: null,
    //         totalSteps: null,
    //         progressCounter: null),
    //   );
    //
    //   try {
    //     pickedImages.state = [];
    //     currentImage.state = null;
    //     globalQualitySlider.state = null;
    //     List<ImageData> picked = [];
    //
    //     for (var sharedFile in sharedFiles) {
    //       final file = File(sharedFile.path);
    //
    //       final imageBytes = await file.readAsBytes();
    //       final decodedImage = img.decodeImage(imageBytes);
    //
    //       picked.add(ImageData(
    //         imageFile: File(file.path),
    //         pixelWidth: decodedImage?.width ?? 1080,
    //         pixelHeight: decodedImage?.height ?? 1080,
    //         quality: 90,
    //       ));
    //     }
    //
    //     pickedImages.state = picked;
    //     currentImage.state = picked[0];
    //     currentImageIndex.state = 0;
    //     setIsLoading(LoadingData(isLoading: false));
    //   } catch (e) {
    //     await showResult("Cannot access shared files - ${e.toString()}");
    //     setIsLoading(LoadingData(isLoading: false));
    //   }
    // }
  }

  Future<SummaryReport?> compressVideo({
    required Function(SummaryReport summaryReport) onComplete,
}) async {
    try {
      if (videoFile.state == null) return null;
      final originalFile = videoFile.state!;
      setIsCompressing(true);
      percentageComplete.state = 0;

      final data = await getVideoData(originalFile);
      if (data == null || data.frameRate == null || data.pixelHeight == null || data.pixelWidth == null) {
        await showResult('Error retrieving video properties');
        setIsCompressing(false);
        return null;
      }

      final outputDir = await getTemporaryDirectory();
      final outPath = '${outputDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.mp4';

      final crf = (35 - ((globalQualitySlider.state / 100) * (35 - 18))).round();
      final command = "-i ${originalFile.path} -vcodec libx264 -crf $crf -preset $selectedPreset $outPath";

      _currentSession  = await FFmpegKit.executeAsync(
        command,
            (session) async {
          final returnCode = await session.getReturnCode();
          if (ReturnCode.isSuccess(returnCode)) {
            // ✅ Success
            final compressedFile = File(outPath);
            final sizeBefore = originalFile.lengthSync();
            final sizeAfter = compressedFile.lengthSync();

            File finalFile;
            if (sizeAfter >= sizeBefore) {
              finalFile = originalFile;
            } else {
              finalFile = compressedFile;
            }

            final saved = sizeBefore - sizeAfter;
            final savedPercent = (saved / sizeBefore).clamp(0, 1).toDouble();

            await saveLocalVideo(compressedFile);
            removeVideo();
            clearCacheDir();

            setIsCompressing(false);
            setIsLoading(false);

            final path = Platform.isAndroid ? "Pictures/Petit" : "Photos";
            final summary = SummaryReport(
              originalSizeBytes: formatBytes(sizeBefore),
              compressedSizeBytes: formatBytes(sizeAfter),
              savedBytes: formatBytes(saved),
              savedPercent: savedPercent,
              path: path,
            );
            onComplete(summary);

            // This can be returned from wherever you're awaiting compressVideo()
            // or use a callback
          } else {
            await showResult('Compression failed.');
            setIsCompressing(false);
            setIsLoading(false);
          }
        },
            (log) => debugPrint('FFmpeg log: ${log.getMessage()}'),
            (statistics) {
          final progress = statistics.getTime();
          final duration = videoController.state?.value.duration.inMilliseconds ?? 1;
          final percent = (progress / duration * 100).clamp(0, 100).toInt();
          percentageComplete.state = percent;
        },
      );

      // You don't need to return anything from here because the result will come from the callback.
    } catch (e) {
      await showResult('Error compressing video: $e');
      setIsCompressing(false);
      setIsLoading(false);
    }
    return null; // or return the summary in the callback above
  }



  Future<VideoData?> getVideoData(File videoFile) async {
    try {
      final session = await FFprobeKit.getMediaInformation(videoFile.path);
      final info = session.getMediaInformation();

      if (info != null) {
        final videoStreams = info.getStreams().where((s) =>
        s.getType() == 'video');
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
            videoFile: videoFile,
            pixelWidth: videoStream.getWidth(),
            pixelHeight: videoStream.getHeight(),
            frameRate: frameRate
        );
      } else {
        showResult('Could not retrieve media information.');
      }
    } catch (e){
      showResult('Error retrieving media information: $e');
    }
    return null;
  }


  Future<void> saveLocalVideo(File compressedImage) async {
    try {
      await GallerySaver.saveVideo(compressedImage.path, albumName: "Petit");
    } catch (e) {
      await showResult("Error ocurred - ${e.toString()}");
    }
  }

  String formatBytes(int bytes, [int decimals = 2]) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB"];
    final i = (bytes == 0) ? 0 : (bytes.bitLength / 10).floor();
    final size = bytes / (1 << (10 * i));
    return '${size.toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  Future<void> clearCacheDir() async {
    final tempDir = await getTemporaryDirectory();

    if (await tempDir.exists()) {
      try {
        final tempDir = await getTemporaryDirectory();

        if (!await tempDir.exists()) return;

        final entities = tempDir.listSync(recursive: true);

        for (final entity in entities) {
          try {
            if (entity is File && await entity.exists()) {
              await entity.delete();
              debugPrint("🗑️ Deleted file: ${entity.path}");
            } else if (entity is Directory && await entity.exists()) {
              await entity.delete(recursive: true);
              debugPrint("🗑️ Deleted directory: ${entity.path}");
            } else {
              debugPrint("⚠️ Skipped (not found): ${entity.path}");
            }
          } catch (e) {
            debugPrint("❌ Failed to delete ${entity.path}: $e");
          }
        }
        debugPrint('Cache cleared');
      } catch (e) {
        debugPrint('Error clearing cache: $e');
      }
    }
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
    _currentSession?.cancel();
    setIsCompressing(false);
    setIsLoading(false);
  }
}
