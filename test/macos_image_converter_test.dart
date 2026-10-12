import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petit/features/images/data/services/macos_image_converter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(MacosImageConverter.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('sends the paths and quality and reports success', () async {
    MethodCall? received;
    messenger.setMockMethodCallHandler(channel, (call) async {
      received = call;
      return '/out.jpg';
    });

    final ok = await MacosImageConverter()
        .convertToJpeg('/in.heic', '/out.jpg', quality: 0.8);

    expect(ok, isTrue);
    expect(received!.method, 'convertToJpeg');
    expect(received!.arguments,
        {'input': '/in.heic', 'output': '/out.jpg', 'quality': 0.8});
  });

  test('reports failure when the native side returns an error', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'convert_failed', message: 'nope');
    });

    expect(await MacosImageConverter().convertToJpeg('/in.heic', '/out.jpg'),
        isFalse);
  });

  test('reports failure when there is no native side (not macOS)', () async {
    expect(await MacosImageConverter().convertToJpeg('/in.heic', '/out.jpg'),
        isFalse);
  });
}
