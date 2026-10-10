import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:petit/common/domain/services/media_saver.dart';
import 'package:petit/core/utils/platform_utils.dart';

class GalleryMediaSaver implements MediaSaver {
  static const _album = "Petit";

  @override
  Future<void> saveImage(String path) async {
    await GallerySaver.saveImage(path, albumName: _album);
  }

  @override
  Future<void> saveVideo(String path) async {
    await GallerySaver.saveVideo(path, albumName: _album);
  }

  @override
  String get imageDestinationLabel =>
      PlatformInfo.isAndroid ? "Pictures/Petit" : "Photos";

  @override
  String get videoDestinationLabel =>
      PlatformInfo.isAndroid ? "Movies/Petit" : "Photos";
}
