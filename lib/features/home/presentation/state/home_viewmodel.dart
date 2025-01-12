import 'package:flutter_super/flutter_super.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';

HomeViewModel get getHomeViewModel => Super.init(HomeViewModel());

class HomeViewModel {
  final result = RxT<String?>(null);
  final isLoading = RxBool(false);
  final pickedImages = RxList<File>(List.empty());

  void setIsLoading(bool isLoading) {
    this.isLoading.state = isLoading;
  }

  void showResult(String result) {
    this.result.state = result;
    this.result.state = null;
  }

  Future<File> pickSingleFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      PlatformFile file = result.files.first;
      File pickedFile = File(file.path!);
      return File(pickedFile.path);
    } else {
      showResult("No file picked!");

      throw Exception('No file picked');
    }
  }

  Future<List<File>> pickMultipleFiles() async {
    FilePickerResult? result =
        await FilePicker.platform.pickFiles(allowMultiple: true);

    if (result != null) {
      var picked = result.paths.map((path) => File(path!)).toList();
      pickedImages.state = picked;
      showResult("No file picked!");
      return picked;
    } else {
      showResult("No file picked!");
      throw Exception('No file picked');
    }
  }

  Future<XFile> compressImage({
    required File file,
    required int quality,
    int minWidth = 1000,
    int minHeight = 1000,
  }) async {
    final filePath = file.absolute.path;
    final lastIndex = filePath.lastIndexOf(RegExp(r'.jp'));
    final splitted = filePath.substring(0, (lastIndex));
    final outPath = "${splitted}_out${filePath.substring(lastIndex)}";

    var compressedImage = await FlutterImageCompress.compressAndGetFile(
        filePath, outPath,
        minWidth: minWidth, minHeight: minHeight, quality: quality);

    if (compressedImage != null) {
      return compressedImage;
    } else {
      showResult("Error compressing image!");
      throw Exception('Error compressing image');
    }
  }

  Future<void> saveLocalImage(XFile compressedImage) async {
    try {
      await GallerySaver.saveImage(compressedImage.path);
      showResult("Image Saved to Galery!");
    } catch (e) {
      showResult("Error ocurred - ${e.toString()}");
    }
  }
}
