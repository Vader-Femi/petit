import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Petit"),
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(10, 0, 10, 15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Spacer(),
            Text(
              "The selected file will show here",
              style: TextStyle(fontSize: 18),
            ),
            Spacer(),
            ElevatedButton(
              onPressed: () async {
                var pickedFile = await _pickSingleFile(context);
                var compressedFile =
                    await compressImage(file: pickedFile, quality: 90);
                if (compressedFile != null) {
                  _saveLocalImage(
                      context: context, compressedImage: compressedFile);
                }
              },
              child: const Text('Pick a File'),
            ),
          ],
        ),
      ),
    );
  }

  Future<File> _pickSingleFile(BuildContext context) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      PlatformFile file = result.files.first;
      File pickedFile = File(file.path!);
      return File(pickedFile.path);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("No file picked!")));

      throw Exception('No file picked');
    }
  }

  Future<List<File>> _pickMultipleFiles(BuildContext context) async {
    FilePickerResult? result =
        await FilePicker.platform.pickFiles(allowMultiple: true);

    if (result != null) {
      return result.paths.map((path) => File(path!)).toList();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("No file picked!")));

      throw Exception('No file picked');
    }
  }

  Future<XFile?> compressImage({
    required File file,
    required int quality,
    int minWidth = 1000,
    int minHeight = 1000,
  }) async {
    final filePath = file.absolute.path;
    final lastIndex = filePath.lastIndexOf(RegExp(r'.jp'));
    final splitted = filePath.substring(0, (lastIndex));
    final outPath = "${splitted}_out${filePath.substring(lastIndex)}";

    return await FlutterImageCompress.compressAndGetFile(filePath, outPath,
        minWidth: minWidth, minHeight: minHeight, quality: quality);
  }

  Future<void> _saveLocalImage({
    required BuildContext context,
    required XFile compressedImage,
  }) async {
    try {
      GallerySaver.saveImage(compressedImage.path);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Image Saved to Galery!")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error ocurred - ${e.toString()}")));
    }
  }
}

// List<File> compressedFiles = List.empty();
//
// for (var file in files) {
// var compressed = await compressImage(file: file, quality: quality);
// compressedFiles.add(File(compressed!.path));
// }
//
// return compressedFiles;
