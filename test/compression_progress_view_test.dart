import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petit/common/widgets/compression_progress_view.dart';

Future<void> _show(WidgetTester tester, CompressionProgressView view) {
  return tester.pumpWidget(MaterialApp(
    home: Scaffold(body: Stack(children: [view])),
  ));
}

void main() {
  testWidgets('shows the title, percent and detail', (tester) async {
    await _show(
      tester,
      const CompressionProgressView(
        title: 'Compressing images',
        percent: 42,
        detail: 'Image 3 of 8',
      ),
    );

    expect(find.text('Compressing images'), findsOneWidget);
    expect(find.text('42%'), findsOneWidget);
    expect(find.text('Image 3 of 8'), findsOneWidget);
  });

  testWidgets('says it is estimating until the time left is known',
      (tester) async {
    await _show(
      tester,
      const CompressionProgressView(
          title: 'Compressing video', percent: 5, showEta: true),
    );
    expect(find.text('Estimating time...'), findsOneWidget);

    await _show(
      tester,
      const CompressionProgressView(
        title: 'Compressing video',
        percent: 50,
        showEta: true,
        eta: Duration(minutes: 2),
      ),
    );
    expect(find.text('about 2 minutes left'), findsOneWidget);
    expect(find.text('Estimating time...'), findsNothing);
  });

  testWidgets('has no time line unless asked for', (tester) async {
    await _show(
      tester,
      const CompressionProgressView(title: 'Compressing images', percent: 50),
    );
    expect(find.textContaining('left'), findsNothing);
    expect(find.text('Estimating time...'), findsNothing);
  });

  testWidgets('without a percent it is an endless spinner', (tester) async {
    await _show(tester, const CompressionProgressView(title: 'Loading video'));

    final indicator = tester
        .widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator));
    expect(indicator.value, isNull);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('shows the keep-open reminder only when asked', (tester) async {
    await _show(
      tester,
      const CompressionProgressView(
          title: 'Compressing', percent: 1, keepOpenHint: true),
    );
    expect(find.textContaining('keep the app open'), findsOneWidget);

    await _show(
      tester,
      const CompressionProgressView(title: 'Compressing', percent: 1),
    );
    expect(find.textContaining('keep the app open'), findsNothing);
  });

  testWidgets('blocks taps on what is underneath', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => tapped = true,
            ),
          ),
          const CompressionProgressView(title: 'Compressing', percent: 1),
        ]),
      ),
    ));

    await tester.tapAt(const Offset(10, 10));
    expect(tapped, isFalse);
  });
}
