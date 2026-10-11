import 'package:flutter_test/flutter_test.dart';
import 'package:petit/core/utils/format_bytes.dart';

void main() {
  test('zero and negative sizes', () {
    expect(formatBytes(0), '0 B');
    expect(formatBytes(-5), '0 B');
  });

  test('picks the unit from the size', () {
    expect(formatBytes(500), '500.00 B');
    expect(formatBytes(1024), '1.00 KB');
    expect(formatBytes(1536), '1.50 KB');
    expect(formatBytes(1048576), '1.00 MB');
    expect(formatBytes(1073741824), '1.00 GB');
  });

  test('decimals can be changed', () {
    expect(formatBytes(1536, 0), '2 KB');
    expect(formatBytes(1536, 1), '1.5 KB');
  });
}
