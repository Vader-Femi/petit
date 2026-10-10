import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:petit/core/utils/work_dir.dart';
import 'package:petit/features/videos/domain/services/video_thumbnailer.dart';

class FfmpegVideoThumbnailer implements VideoThumbnailer {
  @override
  Future<File?> thumbnail(File video) async {
    try {
      final dir = await getPreviewDir();
      final out = File(p.join(
          dir.path, 'preview_${DateTime.now().microsecondsSinceEpoch}.jpg'));

      // Skip the first second (often black); fall back to the very first
      // frame for clips shorter than that.
      for (final seek in const ['00:00:01', '00:00:00']) {
        final session = await FFmpegKit.executeWithArguments([
          '-y',
          '-ss',
          seek,
          '-i',
          video.path,
          '-frames:v',
          '1',
          '-vf',
          'scale=960:-2',
          '-q:v',
          '3',
          out.path,
        ]);
        final code = await session.getReturnCode();
        if (ReturnCode.isSuccess(code) &&
            await out.exists() &&
            await out.length() > 0) {
          return out;
        }
      }
    } catch (e) {
      debugPrint('Video thumbnail failed: $e');
    }
    return null;
  }
}
