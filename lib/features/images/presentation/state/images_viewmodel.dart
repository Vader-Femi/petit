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
import 'package:path/path.dart' as p;
import 'package:petit/core/utils/media_formats.dart';
import 'package:petit/core/utils/work_dir.dart';
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

  /// Reads the pixel size of [path]. HEIC/HEIF files are converted to a
  /// temporary JPEG first because image_size_getter cannot read them.
  /// Falls back to 1080x1080 (the previous behaviour) when the size is unknown.
  Future<({int width, int height})> _readImageSize(String path) async {
    var width = 1080;
    var height = 1080;

    String? readablePath;
    if (isImageSizeGetterSupported(path)) {
      readablePath = path;
    } else if (isHeif(path)) {
      readablePath = await HeifConverter.convert(path, format: "jpg");
    }

    if (readablePath != null) {
      final size =
          ImageSizeGetter.getSizeResult(FileInput(File(readablePath))).size;
      width = size.width;
      height = size.height;
    }

    return (width: width, height: height);
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
          final size = await _readImageSize(path);

          picked.add(ImageData(
            imageFile: File(path),
            pixelWidth: size.width,
            pixelHeight: size.height,
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
          final size = await _readImageSize(path);

          picked.add(ImageData(
            imageFile: File(path),
            pixelWidth: size.width,
            pixelHeight: size.height,
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
      if (!isCompressibleImage(filePath)) {
        await showResult(
            "Unsupported- Only supports png,webp,jpeg,jpg,heic and heif");
        setIsLoading(LoadingData(isLoading: false));
        return null;
      }

      // Intermediate and output files go into a private job folder, never
      // next to the user's original file (which could overwrite a real photo
      // on desktop, e.g. photo.png -> photo.jpg).
      final jobDir = await createJobDir();
      final baseName = p.basenameWithoutExtension(filePath);

      if (!isJpeg(filePath)) {
        final jpgFile = File(p.join(jobDir.path, "$baseName.jpg"));

        if (isHeif(filePath)) {
          final jpgPath = await HeifConverter.convert(filePath, format: "jpg");
          if (jpgPath == null) {
            await showResult("Invalid HEIC/HEIF file");
            setIsLoading(LoadingData(isLoading: false));
            return null;
          }

          //Resize, Rotate, then replace the file path
          final jpgImage = img.decodeImage(await File(jpgPath).readAsBytes());
          final resizedImage = img.copyResize(jpgImage!,
              width: imageData.pixelWidth, height: imageData.pixelHeight);
          // TODO: this hardcoded 90 degree rotation is kept from the old code;
          // verify it per platform (orientation differs on desktop).
          final rotatedJpgImage = img.copyRotate(resizedImage, angle: 90);

          await jpgFile.writeAsBytes(img.encodeJpg(rotatedJpgImage));
        } else {
          //Re encode png/webp to jpg
          final image = img.decodeImage(await imageData.imageFile.readAsBytes())!;
          await jpgFile.writeAsBytes(img.encodeJpg(image));
        }

        filePath = jpgFile.path;
      }

      final outPath = p.join(
          jobDir.path, "${baseName}_compressed${p.extension(filePath)}");

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

      await clearTempFiles();

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
