import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:petit/core/utils/media_formats.dart';
import 'package:petit/core/utils/work_dir.dart';
import 'package:petit/features/images/data/services/desktop_heif_converter.dart';
import 'package:petit/features/images/domain/services/image_previewer.dart';

/// HEIC previews on desktop: a screen-sized JPEG next to the work files.
class DesktopImagePreviewer implements ImagePreviewer {
  DesktopImagePreviewer(this._converter);

  /// Big enough for the carousel on a large monitor.
  static const maxLongSide = 1600;

  final DesktopHeifConverter _converter;

  @override
  Future<File?> createPreview(String path) async {
    if (!isHeif(path)) return null;

    try {
      final jobDir = await createJobDir();
      final out = p.join(jobDir.path, '${p.basenameWithoutExtension(path)}_preview.jpg');
      return await _converter.toJpeg(path, out, maxLongSide: maxLongSide)
          ? File(out)
          : null;
    } catch (_) {
      return null;
    }
  }
}
