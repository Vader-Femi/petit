import 'dart:ui';
import 'package:async/src/cancelable_operation.dart';
import 'package:flutter_super/flutter_super.dart';
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:heif_converter_plus/heif_converter.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:petit/features/home/data/image_data.dart';
import '../../data/loading_data.dart';

HomeViewModel get getHomeViewModel => Super.init(HomeViewModel());

class HomeViewModel {
  final result = RxT<String?>(null);
  final isLoading = RxT<LoadingData>(LoadingData(isLoading: false));
  final pickedImages = RxList<ImageData>([]);
  final currentImage = RxT<ImageData?>(null);
  final currentImageIndex = RxT<int?>(null);
  final globalQualitySlider = RxT<int?>(null);

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
          quality: 90,
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
  }

  Future<void> pickMultipleImages() async {
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
        final imageBytes = await file.readAsBytes();
        final decodedImage = img.decodeImage(imageBytes);

        picked.add(ImageData(
          imageFile: File(file.path),
          pixelWidth: decodedImage?.width ?? 1080,
          pixelHeight: decodedImage?.height ?? 1080,
          quality: 90,
        ));

      }

      pickedImages.state = picked;
      currentImage.state = picked[0];
      currentImageIndex.state = 0;
      setIsLoading(LoadingData(isLoading: false));
    } else {
      await showResult("No file picked!");
      setIsLoading(LoadingData(isLoading: false));
      throw Exception('No file picked');
    }
  }

  Future<XFile> compressImage({required ImageData imageData}) async {
    try {

      var filePath = imageData.imageFile.path;
      final supportedFormatIndex = filePath.lastIndexOf(RegExp(r'(.png|.webp|.jp|.heic|.heif)'));
      if (supportedFormatIndex == -1){
        await showResult("Unsupported- Only supports png,webp,jpeg,jpg,heic and heif");
        setIsLoading(LoadingData(isLoading: false));
        throw Exception("Unsupported- Only supports png,webp,jpeg,jpg,heic and heif");
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
            final resizedImage = img.copyResize(jpgImage!, width: imageData.pixelWidth, height: imageData.pixelHeight);
            final rotatedJpgImage = img.copyRotate(resizedImage, angle: 90);

            final splitted = filePath.substring(0, (heifOrHeicIndex));
            final file = File("$splitted.jpg")
              ..writeAsBytesSync(img.encodeJpg(rotatedJpgImage));

            filePath = file.path;
            lastIndex = filePath.lastIndexOf(RegExp(r'.jp'));
          } else {
            await showResult("Invalid HEIC/HEIF file");
            setIsLoading(LoadingData(isLoading: false));
            throw Exception("Invalid HEIC/HEIF file");
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
      );

      if (compressedImage != null) {
        return compressedImage;
      } else {
        await showResult("Error compressing image!");
        throw Exception('Error compressing image');
      }
    } catch (e) {
      await showResult("Error compressing image - ${e.toString()}");
      setIsLoading(LoadingData(isLoading: false));
      throw Exception("Error compressing image - ${e.toString()}");
    }
  }

  Future<void> saveLocalImage(XFile compressedImage) async {
    try {
      await GallerySaver.saveImage(compressedImage.path);
    } catch (e) {
      setIsLoading(LoadingData(isLoading: false));
      await showResult("Error ocurred - ${e.toString()}");
    }
  }

  Future<void> compressAllSelectedImages(
      CancelableCompleter<void>? completer) async {
    if (!isLoading.state.isLoading) {
      if (pickedImages.isEmpty) {
        await showResult("Select images first");
        return;
      }

      final totalLength = pickedImages.state.length;
      var progress = totalLength == 1 ? 50 : 0;

      for (final (index, imageData) in pickedImages.state.indexed) {
        if (completer?.isCanceled == true) {
          break;
        } else {

          setIsLoading(
            LoadingData(
                isLoading: true,
                completedSteps: index,
                totalSteps: totalLength,
                progressCounter: progress),
          );

          await getHomeViewModel
              .compressImage(imageData: imageData)
              .then((compressedFile) async {
            await saveLocalImage(compressedFile);
          });

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
      pickedImages.state = [];

      setIsLoading(
        LoadingData(
            progressCounter: 100,
            isLoading: false,
            completedSteps: totalLength,
            totalSteps: totalLength),
      );

      await showResult("Image(s) Saved to Galery!");
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
