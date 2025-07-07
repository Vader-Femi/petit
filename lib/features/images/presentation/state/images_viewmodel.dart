import 'dart:ui';
import 'package:async/async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_super/flutter_super.dart';
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:heif_converter_plus/heif_converter.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:image_size_getter/file_input.dart';
import 'package:image_size_getter/image_size_getter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:petit/features/images/data/image_data.dart';
import 'package:share_handler/share_handler.dart';
import '../../data/loading_data.dart';
import '../../../../common/data/summary_report.dart';

ImagesViewModel get getImagesViewModel => Super.init(ImagesViewModel());

class ImagesViewModel {
  final result = RxT<String?>(null);
  final isLoading = RxT<LoadingData>(LoadingData(isLoading: false));
  final pickedImages = RxList<ImageData>([]);
  final currentImage = RxT<ImageData?>(null);
  final currentImageIndex = RxT<int?>(null);
  final globalQualitySlider = RxT<int?>(null);
  final isFabOpen = RxT<bool>(true);

  CancelableCompleter<void> completer = CancelableCompleter();

  void setIsLoading(LoadingData loadingData) {
    isLoading.state = loadingData;
  }

  Future<void> showResult(String? result) async {
    this.result.state = result;
  }

  Future<void> updateCurrentImageAndIndex(int index) async {
    final image = pickedImages.state.elementAt(index);
    currentImage.state = image;
    currentImageIndex.state = index;
  }

  void updateCurrentImageQuality(double value) {
    if (currentImage.state != null) {
      final currentImageIndex =
          pickedImages.state.indexOf(currentImage.state!, 0);

      final newImageData =
          currentImage.state!.copyWith(quality: (value * 100).toInt());
      pickedImages.state[currentImageIndex] = newImageData;
      currentImage.state = newImageData;

      if (globalQualitySlider.state != null) {
        globalQualitySlider.state = null;
      }
    }
  }

  void updateGlobalQualitySlider(double value) {
    globalQualitySlider.state = (value * 100).toInt();
  }

  Future<void> pickSingleImage() async {

    try {
      setIsLoading(
        LoadingData(
            isLoading: true,
            completedSteps: null,
            totalSteps: null,
            progressCounter: null),
      );

      final result = await ImagePicker().pickImage(source: ImageSource.gallery);

      if (result != null) {
        pickedImages.state = [];
        currentImage.state = null;
        currentImageIndex.state = null;
        globalQualitySlider.state = null;

        final imageBytes = await result.readAsBytes();
        final buffer = await ImmutableBuffer.fromUint8List(imageBytes);
        final descriptor = await ImageDescriptor.encoded(buffer);

        pickedImages.state = [
          ImageData(
            imageFile: File(result.path),
            pixelWidth: descriptor.width,
            pixelHeight: descriptor.height,
            quality: 50,
          ),
        ];

        currentImage.state = pickedImages[0];
        currentImageIndex.state = 0;
        setIsLoading(LoadingData(isLoading: false));

        descriptor.dispose();
        buffer.dispose();
      } else {
        await showResult("No file picked!");
        setIsLoading(LoadingData(isLoading: false));
      }
    } catch (e){
      await showResult("An error ocurred - ${e.toString()}");
      setIsLoading(LoadingData(isLoading: false));
    }
  }

  Future<void> addSharedImages([List<SharedAttachment>? sharedFiles]) async {
    if (sharedFiles != null && sharedFiles.isNotEmpty) {
      if (isLoading.state.isLoading) return;

      try {
        setIsLoading(
          LoadingData(
              isLoading: true,
              completedSteps: null,
              totalSteps: null,
              progressCounter: null),
        );

        pickedImages.state = [];
        currentImage.state = null;
        globalQualitySlider.state = null;
        List<ImageData> picked = [];

        for (var file in sharedFiles) {
          final path = file.path;
          int width = 1080;
          int height = 1080;

          final imageGetterSsupportedFormatIndex =
          path.lastIndexOf(RegExp(r'(.png|.webp|.jp|.gif|.bmp)'));
          if (imageGetterSsupportedFormatIndex == -1) {
            // Check if is HEIF or HEIC
            final isHeicOrHeif = path.toLowerCase().endsWith(".heic") ||
                path.toLowerCase().endsWith(".heif");

            if (isHeicOrHeif) {
              String? jpgPath = await HeifConverter.convert(
                  path, format: "jpg");
              if (jpgPath != null) {
                final size =
                    ImageSizeGetter
                        .getSizeResult(FileInput(File(jpgPath)))
                        .size;
                width = size.width;
                height = size.height;
              }
            }
          } else {
            final size =
                ImageSizeGetter
                    .getSizeResult(FileInput(File(path)))
                    .size;
            width = size.width;
            height = size.height;
          }

          picked.add(ImageData(
            imageFile: File(path),
            pixelWidth: width,
            pixelHeight: height,
            quality: 50,
          ));
        }

        pickedImages.state = picked;
        currentImage.state = picked[0];
        currentImageIndex.state = 0;
        setIsLoading(LoadingData(isLoading: false));
      } catch (e) {
        await showResult("An error ocurred - ${e.toString()}");
        setIsLoading(LoadingData(isLoading: false));
      }
    }
  }

  Future<void> pickMultipleImages() async {
    try {
      setIsLoading(
        LoadingData(
            isLoading: true,
            completedSteps: null,
            totalSteps: null,
            progressCounter: null),
      );

      final result = await ImagePicker().pickMultiImage();

      if (result.isNotEmpty) {
        pickedImages.state = [];
        currentImage.state = null;
        globalQualitySlider.state = null;
        List<ImageData> picked = [];

        for (var file in result) {
          final path = file.path;
          int width = 1080;
          int height = 1080;

          final imageGetterSsupportedFormatIndex =
          path.lastIndexOf(RegExp(r'(.png|.webp|.jp|.gif|.bmp)'));
          if (imageGetterSsupportedFormatIndex == -1) {
            // Check if is HEIF or HEIC
            final isHeicOrHeif = path.toLowerCase().endsWith(".heic") ||
                path.toLowerCase().endsWith(".heif");

            if (isHeicOrHeif) {
              String? jpgPath = await HeifConverter.convert(
                  path, format: "jpg");
              if (jpgPath != null) {
                final size =
                    ImageSizeGetter
                        .getSizeResult(FileInput(File(jpgPath)))
                        .size;
                width = size.width;
                height = size.height;
              }
            }
          } else {
            final size =
                ImageSizeGetter
                    .getSizeResult(FileInput(File(path)))
                    .size;
            width = size.width;
            height = size.height;
          }

          picked.add(ImageData(
            imageFile: File(path),
            pixelWidth: width,
            pixelHeight: height,
            quality: 50,
          ));
        }

        pickedImages.state = picked;
        currentImage.state = picked[0];
        currentImageIndex.state = 0;
        setIsLoading(LoadingData(isLoading: false));
      } else {
        await showResult("No file picked!");
        setIsLoading(LoadingData(isLoading: false));
        return;
      }
    } catch (e){
      await showResult("An error ocurred - ${e.toString()}");
      setIsLoading(LoadingData(isLoading: false));
    }
  }

  Future<XFile?> compressImage({required ImageData imageData}) async {
    try {
      var filePath = imageData.imageFile.path;
      final supportedFormatIndex =
          filePath.lastIndexOf(RegExp(r'(.png|.webp|.jp|.heic|.heif)'));
      if (supportedFormatIndex == -1) {
        await showResult(
            "Unsupported- Only supports png,webp,jpeg,jpg,heic and heif");
        setIsLoading(LoadingData(isLoading: false));
      }

      var lastIndex = filePath.lastIndexOf(RegExp(r'.jp'));
      if (lastIndex == -1) {
        // This means it's not jpeg/jpg
        //Check if is heic/heif then handle it
        final heifOrHeicIndex = filePath.lastIndexOf(RegExp(r'(.heic|.heif)'));
        if (heifOrHeicIndex != -1) {
          String? jpgPath =
              await HeifConverter.convert(filePath, format: "jpg");
          if (jpgPath != null) {
            //Resize, Rotate, then Replace the file path and index
            final jpgImage = img.decodeImage(await File(jpgPath).readAsBytes());
            final resizedImage = img.copyResize(jpgImage!,
                width: imageData.pixelWidth, height: imageData.pixelHeight);
            final rotatedJpgImage = img.copyRotate(resizedImage, angle: 90);

            final splitted = filePath.substring(0, (heifOrHeicIndex));
            final file = File("$splitted.jpg")
              ..writeAsBytesSync(img.encodeJpg(rotatedJpgImage));

            filePath = file.path;
            lastIndex = filePath.lastIndexOf(RegExp(r'.jp'));
          } else {
            await showResult("Invalid HEIC/HEIF file");
            setIsLoading(LoadingData(isLoading: false));
          }
        } else {
          //Re encode to jpg
          final image = img.decodeImage(imageData.imageFile.readAsBytesSync())!;
          lastIndex = filePath.lastIndexOf(RegExp(r'(.png|.webp)'));
          final splitted = filePath.substring(0, (lastIndex));
          final file = File("$splitted.jpg")
            ..writeAsBytesSync(img.encodeJpg(image));

          //Replace file path and index
          filePath = file.path;
          lastIndex = filePath.lastIndexOf(RegExp(r'.jp'));
        }
      }
      final splitted = filePath.substring(0, (lastIndex));
      final outPath = "${splitted}_compressed${filePath.substring(lastIndex)}";

      final compressedImage = await FlutterImageCompress.compressAndGetFile(
        filePath,
        outPath,
        minWidth: imageData.pixelWidth,
        minHeight: imageData.pixelHeight,
        quality: globalQualitySlider.state ?? imageData.quality,
        keepExif: true
      );

      if (compressedImage != null) {
        final originalSize = await File(filePath).length();
        final compressedSize = await compressedImage.length();

        if (compressedSize < originalSize) {
          return compressedImage;
        } else {
          // Compressed is larger or equal; return original
          return XFile(imageData.imageFile.path);
        }
      } else {
        await showResult("Error compressing image!");
      }
    } catch (e) {
      await showResult("Error compressing image - ${e.toString()}");
      setIsLoading(LoadingData(isLoading: false));
    }
    return null;
  }

  Future<void> saveLocalImage(XFile compressedImage) async {
    try {
      await GallerySaver.saveImage(compressedImage.path, albumName: "Petit");
    } catch (e) {
      setIsLoading(LoadingData(isLoading: false));
      await showResult("Error ocurred - ${e.toString()}");
    }
  }

  Future<SummaryReport?> compressAllSelectedImages() async {
    if (!isLoading.state.isLoading) {
      if (pickedImages.isEmpty) {
        await showResult("Select images first");
        return null;
      }

      final totalLength = pickedImages.state.length;
      var progress = totalLength == 1 ? 50 : 0;
      var sizeBeforeCompression = 0;
      var sizeAfterCompression = 0;

      for (final (index, imageData) in pickedImages.state.indexed) {
        if (completer.isCanceled == true) {
          break;
        } else {
          setIsLoading(
            LoadingData(
                isLoading: true,
                completedSteps: index,
                totalSteps: totalLength,
                progressCounter: progress),
          );

          sizeBeforeCompression += imageData.imageFile.lengthSync();

          if (completer.isCanceled == true) break;

          final compressedFile = await compressImage(imageData: imageData);
          if (compressedFile == null) {
            sizeBeforeCompression -= imageData.imageFile.lengthSync();
            continue;
          }

          if (completer.isCanceled == true) break;

          await saveLocalImage(compressedFile);

          sizeAfterCompression += await compressedFile.length();

          if (completer.isCanceled == true) break;

          // await getHomeViewModel
          //     .compressImage(imageData: imageData)
          //     .then((compressedFile) async {
          //   await saveLocalImage(compressedFile);
          //   sizeAfterCompression += await compressedFile.length();
          // });

          progress = (((index + 1) / totalLength) * 100).round();

          setIsLoading(
            LoadingData(
                isLoading: true,
                completedSteps: index + 1,
                totalSteps: totalLength,
                progressCounter: progress),
          );
        }
      }

      currentImage.state = null;
      currentImageIndex.state = 0;
      globalQualitySlider.state = null;

      await clearCacheDir();

      pickedImages.state = [];

      setIsLoading(
        LoadingData(
            progressCounter: 100,
            isLoading: false,
            completedSteps: totalLength,
            totalSteps: totalLength),
      );

      final savedBytes = sizeBeforeCompression - sizeAfterCompression;
      final savedPercent =
          (savedBytes / sizeBeforeCompression).clamp(0, 1).toDouble();

      final String path;
      if (!kIsWeb) {
        path = Platform.isAndroid ? "Pictures/Petit" : "Photos";
      } else {
        path = "Probably downloads";
      }
      return SummaryReport(
          originalSizeBytes: formatBytes(sizeBeforeCompression),
          compressedSizeBytes: formatBytes(sizeAfterCompression),
          savedBytes: formatBytes(savedBytes),
          savedPercent: savedPercent,
          path: path);
    }
    return null;
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

  Future<void> selectImageButtonUseCase() async {
    if (!isLoading.state.isLoading) {
      await pickMultipleImages();
    }
  }

  void cancelCompressingAllImages() {
    final totalLength = pickedImages.state.length;

    currentImage.state = null;
    currentImageIndex.state = 0;
    globalQualitySlider.state = null;
    pickedImages.state = [];

    setIsLoading(
      LoadingData(
          progressCounter: 100,
          isLoading: false,
          completedSteps: totalLength,
          totalSteps: totalLength),
    );
  }
}
