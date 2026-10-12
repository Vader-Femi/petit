import 'package:flutter_test/flutter_test.dart';
import 'package:petit/features/videos/data/services/ffmpeg_arguments.dart';

void main() {
  test('the scale filter is the one verified against real FFmpeg', () {
    // Checked with FFmpeg 6.1: 1280x720 -> 854x480, and a phone video stored
    // rotated -> 480x854, so the shorter side is what is scaled.
    expect(
      ffmpegScaleFilter(480),
      r'scale=w=if(gt(iw\,ih)\,-2\,480):h=if(gt(iw\,ih)\,480\,-2)',
    );
  });

  group('buildVideoArguments', () {
    List<String> build({int? videoBitrateKbps, int? maxShortSide}) =>
        buildVideoArguments(
          inputPath: '/my videos/in.mp4',
          outputPath: '/tmp/out.mp4',
          videoCodec: 'libx264',
          crf: 26,
          preset: 'medium',
          videoBitrateKbps: videoBitrateKbps,
          maxShortSide: maxShortSide,
        );

    test('quality mode uses a constant quality and keeps the size', () {
      expect(build(), [
        '-i', '/my videos/in.mp4',
        '-vcodec', 'libx264',
        '-crf', '26',
        '-preset', 'medium',
        '/tmp/out.mp4',
      ]);
    });

    test('target size mode uses a bitrate with a cap and a buffer, not a crf', () {
      expect(build(videoBitrateKbps: 632), [
        '-i', '/my videos/in.mp4',
        '-vcodec', 'libx264',
        '-b:v', '632k',
        '-maxrate', '948k',
        '-bufsize', '1264k',
        '-preset', 'medium',
        '/tmp/out.mp4',
      ]);
    });

    test('a resolution adds the scale filter before the output file', () {
      final arguments = build(maxShortSide: 720);

      expect(arguments, containsAllInOrder(['-vf', ffmpegScaleFilter(720)]));
      expect(arguments.last, '/tmp/out.mp4');
    });

    test('everything together', () {
      final arguments = build(videoBitrateKbps: 800, maxShortSide: 480);

      expect(arguments, contains('-b:v'));
      expect(arguments, isNot(contains('-crf')));
      expect(arguments, contains(ffmpegScaleFilter(480)));
    });

    test('paths with spaces stay one argument', () {
      expect(build(), contains('/my videos/in.mp4'));
    });
  });
}
