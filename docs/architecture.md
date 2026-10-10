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

Platform implementations (chosen in `service_locator.dart`)

| Interface | Android / iOS | Windows / macOS / Linux |
|---|---|---|
| `MediaPicker` | `ImagePickerMediaPicker` (image_picker) | `FileSelectorMediaPicker` (OS file dialog) |
| `MediaSaver` | `GalleryMediaSaver` (gallery) | `FolderMediaSaver` (folder chosen per job) |
| `ImageCompressor` | `FlutterImageCompressor` (+ HEIC) | `DesktopImageCompressor` (`image` package in an isolate; HEIC via FFmpeg, best effort) |
| `VideoCompressor` | `FfmpegVideoCompressor` | same (FFmpeg Kit supports all five platforms) |
| `VideoThumbnailer` | not used | `FfmpegVideoThumbnailer` (Windows, Linux preview) |

Video preview (`presentation/preview/`): `PlayerVideoPreview` (video_player) on Android,
iOS and macOS; `ThumbnailVideoPreview` (a still frame, no playback) on Windows and Linux,
where video_player has no implementation.

`MediaSaver.prepare()` runs once before a job. On desktop it opens the folder dialog; if the
user cancels, a `MediaException` stops the job before any work is done. Asking per job also
works inside the macOS sandbox, which only grants access to folders chosen in a dialog.

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
