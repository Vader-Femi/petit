import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petit/common/widgets/target_size_field.dart';

const _presets = [5, 10, 25];

/// A parent that owns the size, like the real screens do.
class _Host extends StatefulWidget {
  const _Host({required this.start});

  final int start;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late int value = widget.start;
  final reported = <int>[];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            TargetSizeField(
              valueMb: value,
              presets: _presets,
              onChanged: (mb) => setState(() {
                value = mb;
                reported.add(mb);
              }),
            ),
            TextButton(
              onPressed: () => setState(() => value = 10),
              child: const Text('pick 10'),
            ),
            TextButton(
              onPressed: () => setState(() => value = 42),
              child: const Text('set 42'),
            ),
          ],
        ),
      ),
    );
  }
}

String _text(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

void main() {
  testWidgets('is empty while a preset is chosen', (tester) async {
    await tester.pumpWidget(const _Host(start: 25));
    expect(_text(tester), '');
  });

  testWidgets('shows a custom size', (tester) async {
    await tester.pumpWidget(const _Host(start: 42));
    expect(_text(tester), '42');
  });

  testWidgets('typing reports the size', (tester) async {
    await tester.pumpWidget(const _Host(start: 25));

    await tester.enterText(find.byType(TextField), '37');
    await tester.pump();

    final host = tester.state<_HostState>(find.byType(_Host));
    expect(host.value, 37);
    expect(_text(tester), '37');
  });

  testWidgets('only digits are accepted', (tester) async {
    await tester.pumpWidget(const _Host(start: 25));

    await tester.enterText(find.byType(TextField), '1a2.5');
    await tester.pump();

    expect(_text(tester), '125');
  });

  testWidgets('zero is not reported and shows a message', (tester) async {
    await tester.pumpWidget(const _Host(start: 25));

    await tester.enterText(find.byType(TextField), '0');
    await tester.pump();

    final host = tester.state<_HostState>(find.byType(_Host));
    expect(host.reported, isEmpty);
    expect(host.value, 25);
    expect(find.text('Enter at least 1 MB'), findsOneWidget);
  });

  testWidgets('clearing the box is left alone', (tester) async {
    await tester.pumpWidget(const _Host(start: 42));

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();

    expect(_text(tester), '');
    expect(find.text('Enter at least 1 MB'), findsNothing);
  });

  testWidgets('choosing a preset empties the box', (tester) async {
    await tester.pumpWidget(const _Host(start: 42));

    await tester.tap(find.text('pick 10'));
    await tester.pump();

    expect(_text(tester), '');
  });

  testWidgets('a size set from outside is shown', (tester) async {
    await tester.pumpWidget(const _Host(start: 25));

    await tester.tap(find.text('set 42'));
    await tester.pump();

    expect(_text(tester), '42');
  });
}
