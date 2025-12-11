import 'dart:ui'; // Still needed for ImageDescriptor
import 'package:async/async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_super/flutter_super.dart';
import 'dart:io'; // Still needed for File type, XFile uses it.
// import 'dart:html' as html; // Web spec
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
// import 'package:gallery_saver_plus/gallery_saver.dart'; // Not for web
// import 'package:heif_converter_plus/heif_converter.dart'; // Not for web
import 'package:image/image.dart' as img; // Used for re-encoding non-JPG to JPG if not HEIC
import 'package:image_picker/image_picker.dart';
import 'package:image_size_getter/file_input.dart'; // May need web adaptation if it uses dart:io directly for non-standard formats
import 'package:image_size_getter/image_size_getter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:petit/features/images/data/image_data.dart';
import 'package:share_handler/share_handler.dart'; // Assuming this has web support or is handled
import '../../data/loading_data.dart';
import '../../../../common/data/summary_report.dart';

// See comment in videos_viewmodel.web.dart about this global getter pattern
ImagesViewModelWeb get getImagesViewModelWeb => Super.init(ImagesViewModelWeb());

class ImagesViewModelWeb {
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
      final currentImageIndex = pickedImages.state.indexOf(currentImage.state!, 0);
      final newImageData = currentImage.state!.copyWith(quality: (value * 100).toInt());
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
      setIsLoading(LoadingData(isLoading: true));
      final xFile = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (xFile != null) {
        pickedImages.state = [];
        currentImage.state = null;
        currentImageIndex.state = null;
        globalQualitySlider.state = null;

        // For web, XFile.path is a blob URL. ImageDescriptor.encoded should work with bytes.
        final imageBytes = await xFile.readAsBytes();
        final buffer = await ImmutableBuffer.fromUint8List(imageBytes);
        final descriptor = await ImageDescriptor.encoded(buffer);

        pickedImages.state = [
          ImageData(
            imageFile: File(xFile.path), // File(blob_url)
            pixelWidth: descriptor.width,
            pixelHeight: descriptor.height,
            quality: 50,
          ),
        ];
        currentImage.state = pickedImages[0];
        currentImageIndex.state = 0;
        descriptor.dispose();
        buffer.dispose();
      } else {
        await showResult("No file picked!");
      }
    } catch (e) {
      await showResult("An error occurred - ${e.toString()}");
    } finally {
      setIsLoading(LoadingData(isLoading: false));
    }
  }

  Future<void> _processPickedFiles(List<XFile> files) async {
    pickedImages.state = [];
    currentImage.state = null;
    globalQualitySlider.state = null;
    List<ImageData> newPickedImages = [];

    for (var xFile in files) {
      final path = xFile.path; // This is a blob URL on web
      int width = 1080; // Default
      int height = 1080; // Default

      final lowerPath = path.toLowerCase();
      if (lowerPath.endsWith(".heic") || lowerPath.endsWith(".heif")) {
        await showResult("HEIC/HEIF files are not fully supported on web for preview/dimensions.");
        // Use default dimensions or try to get from ImageDescriptor if possible without conversion
        try {
          final imageBytes = await xFile.readAsBytes();
          final buffer = await ImmutableBuffer.fromUint8List(imageBytes);
          final descriptor = await ImageDescriptor.encoded(buffer);
          width = descriptor.width;
          height = descriptor.height;
          descriptor.dispose();
          buffer.dispose();
        } catch (e) {
          debugPrint("Could not get dimensions for HEIC/HEIF on web: $e");
        }
      } else {
        // For standard web formats (PNG, JPG, GIF, WebP), ImageDescriptor should work
        try {
          final imageBytes = await xFile.readAsBytes();
          final buffer = await ImmutableBuffer.fromUint8List(imageBytes);
          final descriptor = await ImageDescriptor.encoded(buffer);
          width = descriptor.width;
          height = descriptor.height;
          descriptor.dispose();
          buffer.dispose();
        } catch (e) {
          debugPrint("Could not get dimensions for ${xFile.name} on web: $e");
          // Fallback to ImageSizeGetter if ImageDescriptor fails for some common format
          // This part might be tricky as ImageSizeGetter expects a FileInput.
          // For web, direct FileInput(File(blob_url)) might not work for all its internal checks.
          // Sticking to ImageDescriptor for web is safer.
        }
      }
      newPickedImages.add(ImageData(
        imageFile: File(path), // File(blob_url)
        pixelWidth: width,
        pixelHeight: height,
        quality: 50,
      ));
    }
    pickedImages.state = newPickedImages;
    if (pickedImages.isNotEmpty) {
      currentImage.state = pickedImages[0];
      currentImageIndex.state = 0;
    }
  }

  Future<void> pickMultipleImages() async {
    try {
      setIsLoading(LoadingData(isLoading: true));
      final result = await ImagePicker().pickMultiImage();
      if (result.isNotEmpty) {
        await _processPickedFiles(result);
      } else {
        await showResult("No files picked!");
      }
    } catch (e) {
      await showResult("An error occurred - ${e.toString()}");
    } finally {
      setIsLoading(LoadingData(isLoading: false));
    }
  }

  Future<XFile?> compressImage({required ImageData imageData}) async {
    try {
      var originalXFile = XFile(imageData.imageFile.path); // imageFile.path is blob URL
      var filePathForCompression = originalXFile.path; // Path to be passed to FlutterImageCompress
      String outPathName = originalXFile.name.isNotEmpty ? originalXFile.name : "compressed_image.jpg";

      final lowerFilePath = filePathForCompression.toLowerCase();
      if (lowerFilePath.endsWith(".heic") || lowerFilePath.endsWith(".heif")) {
        await showResult("HEIC/HEIF compression might not be optimal on web. No pre-conversion to JPG.");
        // FlutterImageCompress will attempt to handle the HEIC/HEIF directly if its web version can.
        // Ensure outPathName has a compatible extension if FlutterImageCompress doesn't change it.
        // e.g. if output is always JPG from the plugin on web, then .jpg is fine.
      } else if (!lowerFilePath.endsWith(".jpg") && !lowerFilePath.endsWith(".jpeg") && !lowerFilePath.endsWith(".png") && !lowerFilePath.endsWith(".webp")) {
        // For other non-standard types that are not HEIC (e.g. some BMP, TIFF if somehow picked)
        // and are not directly supported by FlutterImageCompress on web,
        // we might try to re-encode to JPG using image package.
        // However, image_picker on web usually restricts to web-friendly types.
        // This case might be rare. For now, assume FlutterImageCompress handles common web types.
        await showResult("Image format ${originalXFile.name} might not be optimally compressed. Trying anyway.");
      }

      // path_provider's getTemporaryDirectory() for web gives a virtual path.
      final tempDir = await getTemporaryDirectory();
      // Ensure unique name for output in temp virtual dir
      final targetPath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_${outPathName}';

      final compressedXFile = await FlutterImageCompress.compressAndGetFile(
        filePathForCompression, // This is a blob URL
        targetPath, // This is a virtual path
        minWidth: imageData.pixelWidth,
        minHeight: imageData.pixelHeight,
        quality: globalQualitySlider.state ?? imageData.quality,
        keepExif: false, // EXIF handling on web is often problematic, safer to disable.
        // format: CompressFormat.jpeg, // Optionally force output format
      );

      if (compressedXFile != null) {
        final originalSize = await originalXFile.length();
        final compressedSize = await compressedXFile.length();
        if (compressedSize < originalSize) {
          return compressedXFile;
        } else {
          // If not smaller, return a new XFile instance of the original to avoid issues with XFile identity
          // (though for web, originalXFile itself is fine as it's just a path/blob_url)
          return XFile(originalXFile.path);
        }
      } else {
        await showResult("Error compressing image!");
      }
    } catch (e) {
      await showResult("Error compressing image - ${e.toString()}");
    }
    return null;
  }

  // Web specific save using dart:html
  // Future<void> saveLocalImage(XFile compressedImage) async {
  //   try {
  //     final bytes = await compressedImage.readAsBytes();
  //     final blob = html.Blob([bytes]);
  //     final url = html.Url.createObjectUrlFromBlob(blob);
  //     String fileName = compressedImage.name;
  //     if (fileName.isEmpty && compressedImage.path.isNotEmpty) {
  //       // path might be a virtual path like /temp/123224_myimage.jpg
  //       // or a blob URL if original was returned
  //       fileName = compressedImage.path.split('/').last;
  //     }
  //     if (fileName.isEmpty || fileName.startsWith("blob:")) { // Check if filename is blob url
  //       fileName = "downloaded_image.jpg"; // Fallback filename
  //     }
  //
  //     final anchor = html.AnchorElement(href: url)
  //       ..setAttribute("download", fileName)
  //       ..click();
  //     html.Url.revokeObjectUrl(url);
  //     await showResult("Image saved to Downloads.");
  //   } catch (e) {
  //     await showResult("Error occurred while saving - ${e.toString()}");
  //   }
  // }

  Future<void> saveLocalImage(XFile compressedImage) async {
    try {
      // Save the file directly to the gallery
      final saved = await GallerySaver.saveImage(compressedImage.path);
      if (saved == true) {
        await showResult("Image saved to gallery.");
      } else {
        await showResult("Failed to save image.");
      }
    } catch (e) {
      await showResult("Error occurred while saving - ${e.toString()}");
    }
  }

  Future<SummaryReport?> compressAllSelectedImages() async {
    if (isLoading.state.isLoading) return null;
    if (pickedImages.isEmpty) {
      await showResult("Select images first");
      return null;
    }

    final totalLength = pickedImages.state.length;
    setIsLoading(LoadingData(isLoading: true, completedSteps: 0, totalSteps: totalLength, progressCounter: 0));

    var sizeBeforeCompression = 0;
    var sizeAfterCompression = 0;
    List<XFile> filesToSave = [];

    for (final (index, imageData) in pickedImages.state.indexed) {
      if (completer.isCanceled) break;

      isLoading.state = isLoading.state.copyWith(completedSteps: index, progressCounter: (((index) / totalLength) * 100).round());

      sizeBeforeCompression += await XFile(imageData.imageFile.path).length();

      final compressedFile = await compressImage(imageData: imageData);
      if (compressedFile == null) {
        sizeBeforeCompression -= await XFile(imageData.imageFile.path).length(); // Adjust if compression failed
        continue;
      }

      filesToSave.add(compressedFile); // Collect files to save
      sizeAfterCompression += await compressedFile.length();
    }

    if (!completer.isCanceled) {
      for (final fileToSave in filesToSave) {
        await saveLocalImage(fileToSave); // Save each collected file
      }
    }

    currentImage.state = null;
    currentImageIndex.state = 0;
    globalQualitySlider.state = null;
    pickedImages.state = [];
    await clearCacheDir(); // Web version

    setIsLoading(LoadingData(progressCounter: 100, isLoading: false, completedSteps: totalLength, totalSteps: totalLength));

    if (completer.isCanceled) {
      await showResult("Image compression cancelled.");
      return null;
    }

    final savedBytes = sizeBeforeCompression - sizeAfterCompression;
    final savedPercent = (sizeBeforeCompression > 0 && savedBytes > 0) ? (savedBytes / sizeBeforeCompression).clamp(0, 1).toDouble() : 0.0;

    return SummaryReport(
        originalSizeBytes: formatBytes(sizeBeforeCompression),
        compressedSizeBytes: formatBytes(sizeAfterCompression),
        savedBytes: formatBytes(savedBytes),
        savedPercent: savedPercent,
        path: "Downloads"); // Web path
  }

  String formatBytes(int bytes, [int decimals = 2]) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB"];
    final i = (bytes == 0) ? 0 : (bytes.bitLength / 10).floor();
    final size = bytes / (1 << (10 * i));
    return '${size.toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  Future<void> clearCacheDir() async {
    debugPrint("clearCacheDir (web): Called. No-op for now.");
    // Potentially clear FlutterImageCompress specific temporary files if they are known and accessible.
    // final tempDir = await getTemporaryDirectory();
    // final entities = tempDir.listSync(recursive: true); // Careful with listSync on web's virtual fs
    // ... delete logic ...
  }

  Future<void> selectImageButtonUseCase() async {
    if (!isLoading.state.isLoading) {
      await pickMultipleImages();
    }
  }

  void cancelCompressingAllImages() {
    if (!completer.isCompleted && !completer.isCanceled) {
      completer.operation.cancel(); // Cancel the ongoing operation if any
    }
    completer = CancelableCompleter(); // Reset completer for next use

    final totalLength = pickedImages.state.length; // or a cached value of total steps
    currentImage.state = null;
    currentImageIndex.state = 0;
    globalQualitySlider.state = null;
    pickedImages.state = [];
    setIsLoading(LoadingData(progressCounter: 100, isLoading: false, completedSteps: totalLength, totalSteps: totalLength));
    showResult("Image compression cancelled.");
  }
}
