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
- Web is not a supported target (the web variants were removed).

## Adaptive UI and desktop input

- **Layout** (`core/utils/adaptive.dart`): below 600 px the app uses the bottom navigation
  bar; from 600 px a navigation rail. A page whose content area is at least 720 px wide shows
  the preview and its controls side by side (preview left, a 360 px controls column right);
  narrower pages stack them as on a phone.
- **Drag and drop** (`common/widgets/drop_zone.dart`, desktop only): one drop target wraps
  the whole home screen. Dropped files are classified by extension
  (`core/utils/dropped_files.dart`); images go to the Images tab, a video to the Videos tab.
  Folders are expanded one level. Drops are ignored while a job is running, because switching
  tabs clears the other tab's work.
- **Keyboard shortcuts** (`home_screen.dart`; Ctrl on Windows/Linux, Cmd on macOS): `O` add
  files, `Enter` compress, `Del` or `Backspace` clear, `Esc` cancel a running job, `1`/`2`
  switch tab, left/right arrows move through images. They are ignored while a job is running
  (except `Esc`).
- Mouse dragging is enabled for scrollables (`core/utils/app_scroll_behavior.dart`) and the
  image carousel shows previous/next buttons on desktop.

## State management (Riverpod)

Each tab has a **ViewModel**, which is a Riverpod `Notifier` holding one immutable **state** class:

| ViewModel (provider) | State | Role |
|---|---|---|
| `ImagesViewModel` (`imagesViewModelProvider`) | `ImagesState` | picked images, quality settings, progress, one-shot message |
| `VideosViewModel` (`videosViewModelProvider`) | `VideosState` | video, preview, settings, progress, running job |
| `HomeViewModel` (`homeViewModelProvider`) | `int` (selected tab) | tab switching, `isBusy` |

- Pages are `ConsumerStatefulWidget`s: `ref.watch(...)` for the state, `ref.read(....notifier)` to call
  actions. State is never edited in place; ViewModels assign a new state with `copyWith`.
- One-shot messages (`result`) are shown with `ref.listen` and then cleared.
- `core/di/providers.dart` exposes the get_it services (use cases, picker, workspace, preview
  factory) as providers. Tests override them with fakes (`test/helpers/viewmodel_fakes.dart`), so
  the ViewModels are tested without plugins or a device.
- Keep real state inside the state class, not in Notifier fields: Riverpod 3 creates a new Notifier
  if its provider ever rebuilds. The only Notifier field is the cancelable handle of a running image
  job (the provider watches nothing, so it never rebuilds). The carousel controller has its own provider.
- flutter_super is no longer a dependency.
