import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petit/common/domain/media_exception.dart';
import 'package:petit/common/domain/services/media_picker.dart';
import 'package:petit/common/domain/services/media_saver.dart';
import 'package:petit/common/domain/services/workspace.dart';
import 'package:petit/core/di/providers.dart';
import 'package:petit/features/images/domain/entities/image_data.dart';
import 'package:petit/features/images/domain/entities/image_size.dart';
import 'package:petit/features/images/domain/services/image_compressor.dart';
import 'package:petit/features/images/domain/usecases/compress_images.dart';
import 'package:petit/features/images/domain/usecases/read_images.dart';
import 'package:petit/features/videos/domain/entities/video_data.dart';
import 'package:petit/features/videos/domain/services/video_compressor.dart';
import 'package:petit/features/videos/domain/usecases/compress_video.dart';
import 'package:petit/features/videos/presentation/preview/video_preview.dart';

/// Picker that returns what the test sets. Set [gate] to hold a pick open.
class FakePicker implements MediaPicker {
  List<String> images = [];
  String? video;
  Completer<void>? gate;
  int imageCalls = 0;

  @override
  Future<List<String>> pickImages() async {
    imageCalls++;
    if (gate != null) await gate!.future;
    return images;
  }

  @override
  Future<String?> pickVideo() async {
    if (gate != null) await gate!.future;
    return video;
  }
}

class FakeWorkspace implements Workspace {
  int clears = 0;

  @override
  Future<void> clear() async => clears++;
}

class FakeSaver implements MediaSaver {
  bool declineToPrepare = false;
  final saved = <String>[];

  @override
  Future<void> prepare() async {
    if (declineToPrepare) {
      throw const MediaException('No output folder selected.');
    }
  }

  @override
  Future<void> saveImage(String path) async => saved.add(path);

  @override
  Future<void> saveVideo(String path) async => saved.add(path);

  @override
  String get imageDestinationLabel => 'Photos';

  @override
  String get videoDestinationLabel => 'Movies/Petit';
}

/// Every image is 640x480 and compresses to a 40-byte file.
class FakeImageCompressor implements ImageCompressor {
  FakeImageCompressor(this.dir);

  final Directory dir;
  int _counter = 0;

  @override
  Future<ImageSize> readSize(String path) async => const ImageSize(640, 480);

  @override
  Future<File> compress(ImageData image, {required int quality}) async {
    final out = File('${dir.path}/out_${_counter++}.bin');
    await out.writeAsBytes(List.filled(40, 1));
    return out;
  }
}

class FakeVideoTask implements VideoCompressionTask {
  final completer = Completer<File>();
  bool cancelled = false;

  @override
  Future<File> get result => completer.future;

  @override
  Future<void> cancel() async {
    cancelled = true;
  }
}

class FakeVideoCompressor implements VideoCompressor {
  FakeVideoTask? lastTask;
  void Function(int percent)? progressCallback;

  @override
  Future<VideoData> probe(File video) async => VideoData(
        videoFile: video,
        pixelWidth: 1920,
        pixelHeight: 1080,
        videoCodec: 'h264',
        frameRate: 30,
        durationMs: 5000,
      );

  @override
  Future<VideoCompressionTask> start({
    required File input,
    required String videoCodec,
    required int crf,
    required String preset,
    required int totalDurationMs,
    required void Function(int percent) onProgress,
  }) async {
    progressCallback = onProgress;
    return lastTask = FakeVideoTask();
  }
}

class FakeVideoPreview implements VideoPreview {
  FakeVideoPreview({this.initializeError});

  final Object? initializeError;
  bool initialized = false;
  bool disposed = false;

  @override
  Future<void> initialize() async {
    if (initializeError != null) throw initializeError!;
    initialized = true;
  }

  @override
  bool get isInitialized => initialized;

  @override
  Duration get duration => const Duration(seconds: 5);

  @override
  double get aspectRatio => 16 / 9;

  @override
  bool get canPlay => false;

  @override
  bool get isPlaying => false;

  @override
  Future<void> togglePlayback() async {}

  @override
  Widget build(BuildContext context) => const SizedBox();

  @override
  void dispose() {
    disposed = true;
  }
}

/// Wires fakes into a [ProviderContainer] so the ViewModels can be tested
/// without plugins, dialogs or a device.
class Harness {
  Harness(this.dir);

  final Directory dir;
  final picker = FakePicker();
  final workspace = FakeWorkspace();
  final saver = FakeSaver();
  final videoCompressor = FakeVideoCompressor();
  final previews = <FakeVideoPreview>[];

  /// Set to make the next previews fail to initialize.
  Object? previewInitializeError;

  late final imageCompressor = FakeImageCompressor(dir);

  File file(String name, int bytes) =>
      File('${dir.path}/$name')..writeAsBytesSync(List.filled(bytes, 0));

  /// Disposed automatically at the end of the test.
  ProviderContainer container() => ProviderContainer.test(overrides: [
        mediaPickerProvider.overrideWithValue(picker),
        workspaceProvider.overrideWithValue(workspace),
        readImagesUseCaseProvider
            .overrideWithValue(ReadImagesUseCase(imageCompressor)),
        compressImagesUseCaseProvider.overrideWithValue(
            CompressImagesUseCase(imageCompressor, saver)),
        compressVideoUseCaseProvider.overrideWithValue(
            CompressVideoUseCase(videoCompressor, saver)),
        videoPreviewFactoryProvider.overrideWithValue((file) {
          final preview =
              FakeVideoPreview(initializeError: previewInitializeError);
          previews.add(preview);
          return preview;
        }),
      ]);
}
