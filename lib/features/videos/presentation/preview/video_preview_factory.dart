import 'dart:io';

import 'package:petit/core/utils/platform_utils.dart';
import 'package:petit/features/videos/domain/services/video_compressor.dart';
import 'package:petit/features/videos/domain/services/video_thumbnailer.dart';
import 'package:petit/features/videos/presentation/preview/player_video_preview.dart';
import 'package:petit/features/videos/presentation/preview/thumbnail_video_preview.dart';
import 'package:petit/features/videos/presentation/preview/video_preview.dart';
import 'package:petit/service_locator.dart';

/// `video_player` has no Windows or Linux implementation, so those platforms
/// get a still-frame preview. Everything else plays the video.
VideoPreview createVideoPreview(File file) {
  if (PlatformInfo.isWindows || PlatformInfo.isLinux) {
    return ThumbnailVideoPreview(
      file,
      sl<VideoCompressor>(),
      sl<VideoThumbnailer>(),
    );
  }
  return PlayerVideoPreview(file);
}
