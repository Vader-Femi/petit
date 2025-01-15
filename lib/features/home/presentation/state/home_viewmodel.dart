import 'dart:ui';
import 'package:flutter_super/flutter_super.dart';
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:petit/features/home/data/image_data.dart';

HomeViewModel get getHomeViewModel => Super.init(HomeViewModel());

class HomeViewModel {
  final result = RxT<String?>(null);
  final isLoading = RxBool(false);
  final pickedImages = RxList<ImageData>([]);

  void setIsLoading(bool isLoading) {
    this.isLoading.state = isLoading;
  }

  Future<void> showResult(String? result) async {
    this.result.state = result;
  }

  Future<void> pickSingleImage() async {
    final result = await ImagePicker().pickImage(source: ImageSource.gallery);

    if (result != null) {
      pickedImages.state = List.empty();

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

      descriptor.dispose();
      buffer.dispose();
    } else {
      await showResult("No file picked!");
      setIsLoading(false);
      throw Exception('No file picked');
    }
  }

  Future<void> pickMultipleImages() async {
    final result = await ImagePicker().pickMultiImage();

    if (result.isNotEmpty) {
      pickedImages.state = [];

      List<ImageData> picked = [];

      for (var file in result) {
        final imageBytes = await file.readAsBytes();
        final buffer = await ImmutableBuffer.fromUint8List(imageBytes);
        final descriptor = await ImageDescriptor.encoded(buffer);

        picked.add(ImageData(
          imageFile: File(file.path),
          pixelWidth: descriptor.width,
          pixelHeight: descriptor.height,
          quality: 90,
        ));

        descriptor.dispose();
        buffer.dispose();
      }

      pickedImages.state = picked;
    } else {
      await showResult("No file picked!");
      setIsLoading(false);
      throw Exception('No file picked');
    }
  }

  Future<XFile> compressImage({required ImageData imageData}) async {
    try {
      var filePath = imageData.imageFile.path;
      var lastIndex = filePath.lastIndexOf(RegExp(r'.jp'));
      if(lastIndex == -1){
        //Re encode as jpg
        final image = img.decodeImage(imageData.imageFile.readAsBytesSync())!;
        lastIndex = filePath.lastIndexOf(RegExp(r'(.png|.webp|.heic|.raw)'));
        final splitted = filePath.substring(0, (lastIndex));
        var file = File("$splitted.jpg")..writeAsBytesSync(img.encodeJpg(image));

        //Replace file path and index
        filePath = file.path;
        lastIndex = filePath.lastIndexOf(RegExp(r'.jp'));
      }
      final splitted = filePath.substring(0, (lastIndex));
      final outPath = "${splitted}_out${filePath.substring(lastIndex)}";

      var compressedImage = await FlutterImageCompress.compressAndGetFile(
        filePath,
        outPath,
        minWidth: imageData.pixelWidth,
        minHeight: imageData.pixelHeight,
        quality: imageData.quality,
      );

      if (compressedImage != null) {
        return compressedImage;
      } else {
        await showResult("Error compressing image!");
        throw Exception('Error compressing image');
      }
    } catch (e) {
      await showResult("Error compressing image - ${e.toString()}");
      setIsLoading(false);
      throw Exception("Error compressing image - ${e.toString()}");
    }
  }

  Future<void> saveLocalImage(XFile compressedImage) async {
    try {
      await GallerySaver.saveImage(compressedImage.path);
    } catch (e) {
      setIsLoading(false);
      await showResult("Error ocurred - ${e.toString()}");
    }
  }
}
