import 'package:petit/features/videos/data/slider_value.dart';

/// FFmpeg presets offered by the "Encoding speed" slider. A slower preset
/// gets the same quality into a smaller file but takes longer; it does not set
/// the file size.
final List<SliderValue> kFfmpegPresets = [
  // SliderValue(value: "ultrafast", desc: "ultrafast"),
  // SliderValue(value: "superfast", desc: "superfast"),
  // SliderValue(value: "veryfast", desc: "veryfast"),
  // SliderValue(value: "faster", desc: "faster"),
  SliderValue(value: "fast", desc: "Faster"),
  SliderValue(value: "medium", desc: "Balanced"), // good default
  SliderValue(value: "slow", desc: "Smaller file"),
  // SliderValue(value: "slower", desc: "slower"),
  // SliderValue(value: "veryslow", desc: "veryslow"),
];

/// Label for a 0..100 value of the "Compression Level" slider.
String labelForCrfSlider(int value) {
  if (value <= 20) return "Minimal";
  if (value <= 40) return "Very Light";
  if (value <= 60) return "Light";
  if (value <= 80) return "Moderate";
  return "Heavy";
}
