# Architecture

Petit follows a feature-first clean architecture with ViewModels.

```
lib/
  common/
    domain/        MediaPicker, MediaSaver, Workspace, MediaException
    data/services/ mobile implementations (image_picker, gallery_saver_plus, temp files)
  features/
    images/
      domain/      ImageData, ImageCompressor (interface), ReadImages / CompressImages use cases
      data/        FlutterImageCompressor (flutter_image_compress + HEIC)
      presentation/ ImagesViewModel (state only), pages
    videos/
      domain/      VideoData, CodecConfig, VideoCompressor (interface), CompressVideo use case
      data/        FfmpegVideoCompressor (ffmpeg_kit_flutter_new)
      presentation/ VideosViewModel (state only), pages
  service_locator.dart   wires interfaces to implementations (get_it)
```

Rules

- `domain/` is plain Dart: no Flutter, no plugins, no state-management package.
- ViewModels talk to use cases and domain interfaces only. They never import a plugin
  for picking, compressing or saving.
- Platform differences live in `data/` and are chosen in `service_locator.dart`.
  To support a new platform, add an implementation of the interface and register it
  there (see the `TODO(desktop)` comment).
- Files created while compressing go into the work folder (`core/utils/work_dir.dart`),
  never next to the user's originals.
- The `*_web.dart` files are a frozen, separate web implementation. The old
  `features/*/data/{image_data,video_data,codec_config}.dart` files only re-export
  the domain entities so those web files keep compiling.
