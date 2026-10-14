import 'package:flutter_test/flutter_test.dart';
import 'package:petit/features/videos/data/services/hardware_encoders.dart';
import 'package:petit/features/videos/domain/video_bitrate.dart';

void main() {
  group('fastEncodingBitrateKbps', () {
    int kbps({
      int width = 1920,
      int height = 1080,
      int? frameRate = 30,
      int crf = 23,
      bool hevc = false,
      int? maxShortSide,
      int? sourceKbps,
    }) =>
        fastEncodingBitrateKbps(
          width: width,
          height: height,
          frameRate: frameRate,
          crf: crf,
          hevc: hevc,
          maxShortSide: maxShortSide,
          sourceKbps: sourceKbps,
        );

    test('1080p30 at CRF 23 gets 0.1 bit per pixel', () {
      expect(kbps(), 6221); // 62,208,000 pixels/s x 0.1 / 1000
    });

    test('every 6 CRF steps halve it, and the other way doubles it', () {
      expect(kbps(crf: 29), 3110);
      expect(kbps(crf: 35), 1555);
      expect(kbps(crf: 17), 12442);
    });

    test('HEVC gets less than H.264 at the same quality', () {
      // x265's CRF 28 looks like x264's CRF 23, in about 65% of the bits.
      expect(kbps(crf: 28, hevc: true), 4044);
      expect(kbps(crf: 28, hevc: true), lessThan(kbps(crf: 23)));
    });

    test('more pixels or frames need more', () {
      expect(kbps(frameRate: 60), 12442);
      expect(kbps(width: 3840, height: 2160), 24883);
    });

    test('a missing frame rate counts as 30', () {
      expect(kbps(frameRate: null), kbps(frameRate: 30));
    });

    test('scaling down is by the shorter side, for any orientation', () {
      expect(kbps(maxShortSide: 540), 1555); // a quarter of the pixels
      expect(kbps(width: 1080, height: 1920, maxShortSide: 540), 1555);
    });

    test('a resolution that would not shrink the video changes nothing', () {
      expect(kbps(maxShortSide: 1080), kbps());
      expect(kbps(maxShortSide: 2160), kbps());
    });

    test('is capped just below the source bitrate', () {
      expect(kbps(sourceKbps: 4000), 3600);
      expect(kbps(sourceKbps: 100000), 6221, reason: 'a high cap changes nothing');
    });

    test('never goes below the floor, even for a tiny source', () {
      expect(kbps(sourceKbps: 10), kMinVideoKbps);
      expect(kbps(width: 160, height: 90, crf: 40), kMinVideoKbps);
    });

    test('never goes above the maximum', () {
      expect(kbps(width: 7680, height: 4320, frameRate: 120, crf: 10),
          kMaxFastKbps);
    });
  });

  group('hardwareEncoderCandidates', () {
    test('Apple platforms use VideoToolbox', () {
      expect(hardwareEncoderCandidates('libx264', 'macos'), ['h264_videotoolbox']);
      expect(hardwareEncoderCandidates('libx265', 'ios'), ['hevc_videotoolbox']);
    });

    test('Android uses MediaCodec', () {
      expect(hardwareEncoderCandidates('libx264', 'android'), ['h264_mediacodec']);
    });

    test('Windows tries NVIDIA, Intel, AMD, then Media Foundation', () {
      expect(hardwareEncoderCandidates('libx265', 'windows'),
          ['hevc_nvenc', 'hevc_qsv', 'hevc_amf', 'hevc_mf']);
    });

    test('Linux only tries NVENC, which needs no device set-up', () {
      expect(hardwareEncoderCandidates('libx264', 'linux'), ['h264_nvenc']);
    });

    test('there is nothing to try for VP9 or unknown systems', () {
      expect(hardwareEncoderCandidates('libvpx-vp9', 'windows'), isEmpty);
      expect(hardwareEncoderCandidates('libx264', 'other'), isEmpty);
    });
  });
}
