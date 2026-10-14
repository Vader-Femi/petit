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
| `MediaSaver` | `GalleryMediaSaver` (gallery) | `FolderMediaSaver` (the remembered "Save to" folder, else a dialog per job) |
| `ImageCompressor` | `FlutterImageCompressor` (+ HEIC) | `DesktopImageCompressor` (`image` package in an isolate; HEIC through `DesktopHeifConverter`: macOS ImageIO, then the bundled FFmpeg) |
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
  Folders are expanded one level. Drops are ignored while a job is running, because they would
  replace the tab's selection.
- **Keyboard shortcuts** (`home_screen.dart`; Ctrl on Windows/Linux, Cmd on macOS): `O` add
  files, `Enter` compress, `Del` or `Backspace` clear, `Esc` cancel a running job, `1`/`2`/`3`
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
| `SettingsViewModel` (`settingsViewModelProvider`) | `AppSettings` | the default compression settings |

- Pages are `ConsumerStatefulWidget`s: `ref.watch(...)` for the state, `ref.read(....notifier)` to call
  actions. State is never edited in place; ViewModels assign a new state with `copyWith`.
- One-shot messages (`result`) are shown with `ref.listen` and then cleared.
- `core/di/providers.dart` exposes the get_it services (use cases, picker, workspace, preview
  factory) as providers. Tests override them with fakes (`test/helpers/viewmodel_fakes.dart`), so
  the ViewModels are tested without plugins or a device.
- **Tabs keep their work.** Switching between Images and Videos no longer clears either tab; both
  pages stay alive in an `IndexedStack`. Leaving the Videos tab pauses the player. Only one job runs
  at a time (both tabs share one work folder, which a finishing job empties), so each ViewModel
  refuses to start while the other is busy.
- Keep real state inside the state class, not in Notifier fields: Riverpod 3 creates a new Notifier
  if its provider ever rebuilds. The only Notifier field is the cancelable handle of a running image
  job (the provider watches nothing, so it never rebuilds). The carousel controller has its own provider.
- flutter_super is no longer a dependency.

## Save-to folder (desktop)

The "Save to" tile (`common/widgets/save_to_tile.dart`) on both pages shows where results go and lets
the user change it. The choice is stored by `OutputFolderPreference` (shared_preferences) and read by
`FolderMediaSaver`, which uses it without asking if the folder can still be written to. With nothing
remembered, a dialog opens at the start of each job. After a job the summary offers "Open folder".

## Video options

The Videos tab's options live in `VideoOptionsPanel` and `VideosState`:

- **Quality or Target size.** Quality is a CRF level. Target size aims for a file of about 5, 10, 25, 50
  or 100 MB (1 MB = 1,000,000 bytes) by turning the size and the video's length into a bitrate
  (`domain/video_bitrate.dart`). In tests the result came out 8 to 12 percent under the target, so it is
  an "about". Sizes at or above the video's own size are disabled.
- **Resolution.** Original, 1080p, 720p or 480p, where the number is the *shorter* side, so portrait
  phone videos are handled too. Videos are never enlarged, and only smaller choices are offered.
- **Encoding speed** is the FFmpeg preset. It changes how long encoding takes and how efficient it is,
  not the file size.

`data/services/ffmpeg_arguments.dart` builds the FFmpeg command line as a pure function; its tests check
the exact arguments, which were verified with a real FFmpeg 6.1.

## Image options and size estimate

Under the quality slider, `ImageOptionsPanel` shows the expected size of the current image and two
switches, kept in `ImagesState.options` (`ImageOptions`):

- **Keep transparency** (on by default; only shown for PNG and WebP). Before, every image became a
  JPEG, so transparent areas turned black. Now an image that really has transparent pixels (checked
  by decoding it, because many PNGs have an alpha channel but are fully opaque) stays transparent:
  Android saves WebP (lossy, honours the quality slider), iOS and desktop save PNG (lossless, so the
  slider has little effect; the page says so). Turned off, transparent areas are flattened onto white
  and the image is saved as JPEG. The pure Dart `image` package cannot write WebP, and iOS Photos
  cannot store it, which is why only Android gets WebP.
- **Remove location data** (off by default). Mobile uses `keepExif: false`; desktop replaces the EXIF
  block with an empty one. Neither can drop only the GPS tags, so camera and date go too. When this
  is on, the compressed file is saved even if it is larger than the original, because the original
  still has the location.

The estimate is exact: `EstimateImageSizeUseCase` runs the real compressor on the current image, reads
the size of the result and deletes it. `ImagesViewModel` waits 500 ms after the last change, ignores
results that arrive for older settings, caches results per (file, quality, options), and does not
estimate while a job runs. The panel also says when the result would not be smaller (the original is
kept) or would be larger.

## Settings tab

The third tab (`features/settings/`) holds the default settings: image quality, keep transparency,
remove location data, and for video the size mode (quality or target size), compression level,
target size, resolution and encoding speed. On desktop it also shows the "Save to" folder.

- `AppSettings` (domain) is the value; `SettingsRepository` (domain) is the interface and
  `SharedPrefsSettingsRepository` (data) stores it. Bad or missing stored values fall back to the
  default (`settingsFromMap` is a pure function with its own tests).
- The settings are read once in `initializeDependencies()` and exposed as `initialSettingsProvider`, so
  `SettingsViewModel` and the other ViewModels can read them synchronously from their first build.
- Defaults apply to *new work*: a new selection of images starts at the default quality and options,
  and the Videos tab starts from the video defaults. Changing a default applies at once to a tab that
  has nothing picked, and leaves a selection in progress alone. Changes are saved immediately.

## Custom target size and warnings (videos)

- **Custom size.** Next to the preset chips, `TargetSizeField` takes any whole number of megabytes from 1
  to `kMaxTargetSizeMb` (9999). The same field is on the Settings tab. It is empty while a preset is
  chosen. A video smaller than the smallest preset (5 MB) gets half its own size as the starting
  target.
- **Warnings.** `videoSettingsWarnings` (pure, in `videos/domain/video_warnings.dart`) looks at the
  video and the chosen settings. `VideosState.warnings` feeds a warning box in the options panel.
  - A target that is not smaller than the video **blocks starting** (exact: compressing cannot help).
  - A target below what the video's length allows (`minimumTargetBytes`: the bitrate floor of
    100 kbit/s plus audio) is shown as a warning only. The result will be bigger than the target.
  - In quality mode there is no way to know the result before encoding, so two hints are shown
    ("may not make it smaller"): Minimal compression, and a video that already averages under
    1000 kbit/s. Neither shows when the resolution is lowered, which shrinks the file anyway.
  - Whatever happens, the original is kept when the result is not smaller, and the summary dialog
    says when no space was saved.
- Images get the equivalent from the size estimate (see above): the panel says when the original
  would be kept or the result would be larger.

## Progress screen and welcome screens

- **Progress view.** `CompressionProgressView` (`common/widgets/`) is the overlay both tabs show while
  working: a ring with the percentage, what is happening ("Image 3 of 8"), the time left, and a
  reminder to keep the app open. It uses theme colours (the old overlay was hard-coded black) and
  blocks taps underneath. Loading files shows the same ring, spinning.
- **Time left.** `ProgressEta` (pure Dart, injectable clock) turns "how far along" into "how long to
  go". It stays quiet until the job is 3% done and has run 3 seconds, then blends readings so the
  number does not jump. `formatEta` rounds it ("about 2 minutes left"). Images report progress per
  image, so the estimate is only shown for batches of 3 or more; video uses FFmpeg's percentage,
  which is not perfectly linear, so treat it as a guide.
- **Welcome screens.** `features/onboarding/`: three pages (what Petit does, how to use it, files stay
  on the device) with Skip / Next / Get started. `OnboardingStore` remembers that they were seen
  (read once at start-up, like the settings); `main.dart` shows them instead of `HomeScreen` until
  then. Settings has "Show the welcome tour" to see them again. If the stored answer cannot be read
  they are skipped.

## Compressing in the background (Android)

Without help, Android may freeze or kill the app soon after the user leaves it, which would end a long
compression. While a job runs, Petit now runs a **foreground service** (`CompressionService.kt`) with a
progress notification and a partial wake lock (so the CPU keeps going with the screen off). The
compression itself still runs in Flutter; the service only keeps the process alive and shows progress.

- **Dart side.** `BackgroundKeepAlive` (domain interface) has an Android implementation that talks to
  `MainActivity` over the `com.outsidetheide.petit/keep_alive` method channel, and a no-op one for every
  other platform (desktop apps keep running; iOS does not allow long background work).
  `JobKeepAlive` wraps it for the ViewModels: it never lets a notification problem stop a job, asks for
  the notification permission once, and thins out progress updates (at most one a second, 100% always).
  Both ViewModels start it when a job starts and end it when the job finishes, fails or is cancelled.
- **Android side.** `MainActivity` handles `start`, `update`, `stop` and `requestNotificationPermission`
  (Android 13+). The service uses the `mediaProcessing` type on Android 15+ and `dataSync` before that;
  the manifest declares both, with their permissions, plus `POST_NOTIFICATIONS` and `WAKE_LOCK`.
  `stopWithTask` is on: swiping Petit away from the recent apps ends the job (its Flutter side is gone
  by then), so the service must not outlive it. Declining the notification permission does not stop
  background compression, it only hides the notification.
- **Limits.** Android 15 caps `mediaProcessing`/`dataSync` services at about 6 hours; the wake lock
  expires after 3 hours as a safety net. The job is not resumed if the system kills the app anyway.
- **Play Console.** Apps that declare foreground service types must describe them in the Play Console
  ("Foreground service permissions" on the App content page): explain that Petit compresses the user's
  own photos and videos, which continues when they leave the app, and that the notification shows
  progress.
- Needs `compileSdk` 35 or newer (the `mediaProcessing` manifest value); Flutter's current default is.

## Desktop speed and size

- **Smaller JPEGs.** The desktop encoder now writes JPEG with 4:2:0 chroma, like the phone encoders. The
  `image` package defaults to 4:4:4, which costs noticeably more bytes for no visible gain; a test
  checks the saving.
- **Several images at once.** `CompressImagesUseCase` takes a `concurrency`. Each worker takes the next
  image, compresses and saves it. Desktop uses half the cores, at most 4 (`PlatformInfo.imageConcurrency`;
  every image is decoded in full, so memory is the limit); phones stay at 1 because the native encoder
  already uses several cores. With one worker the progress events are exactly what they were; with more,
  progress counts finished images and they can finish out of order. Cancelling stops new images from
  starting.
- **HEIC on Windows and Linux.** No libheif is needed: the bundled FFmpeg (8.1.2 on every platform in
  `ffmpeg_kit_flutter_new` 4.6.x) reads HEIC itself, tile grids included since 7.1, and the code already
  fell back to it. `DesktopHeifConverter` is that path, shared by the compressor and by
  `DesktopImagePreviewer`, which makes a 1600 px JPEG so the carousel can show a HEIC photo (Flutter
  cannot draw them on desktop). `ImageData.previewFile` carries it; phones use `NoopImagePreviewer`.

## Fast encoding (video hardware)

The normal encoders (libx264, libx265) run on the CPU and give the smallest files. Most machines also
have video hardware (VideoToolbox on Apple, MediaCodec on Android, NVENC/QSV/AMF/Media Foundation on
Windows, NVENC on Linux) that is several times faster but makes somewhat bigger files at the same
quality. "Fast encoding" lets the user pick that trade; it is off by default (Settings has the default).

- **Detection.** `FfmpegVideoCompressor.hardwareEncoderFor` tries the platform's candidate encoders
  (`hardwareEncoderCandidates`) by encoding one second of test video and throwing it away. An encoder
  can be built into FFmpeg without the hardware being there, so only a real encode counts. The answer is
  remembered per codec for the run. The Videos tab runs the check in the background after a video loads
  and shows the switch only if something works (VP9 has no hardware encoder, so no switch).
- **Bitrate.** Hardware encoders have no CRF and no x264 presets, only a bitrate. The quality level is
  turned into one by `fastEncodingBitrateKbps`: 0.1 bit per pixel at CRF 23, halved every 6 CRF steps,
  65% of that for HEVC, scaled with the output resolution, and never above 90% of the source's own
  bitrate. It is an estimate; the point is the right area, not an exact size. A target size uses the
  bitrate it already worked out.
- **Safety net.** If the hardware encode fails part way (driver, format, size), `start` deletes the
  half-written file (FFmpeg will not overwrite it) and runs the normal encode, so asking for hardware
  can make a job faster but not fail. The result is still dropped in favour of the original if it is not
  smaller.
- Presets belong to the software encoder, so the "Encoding speed" box is hidden while Fast encoding is
  on.
