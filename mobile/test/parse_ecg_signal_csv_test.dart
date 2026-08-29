import 'package:cardiolens_app/services/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a plain, header-less signal column', () {
    final values = parseEcgSignalCsv('0.1\n0.2\n0.3');
    expect(values, [0.1, 0.2, 0.3]);
  });

  test('skips a header row and takes the last column of a time+amplitude CSV', () {
    final csv = 'time,amplitude\n0.000,0.10\n0.002,0.20\n0.004,0.15';
    final values = parseEcgSignalCsv(csv);
    expect(values, [0.10, 0.20, 0.15]);
  });

  test('ignores blank lines', () {
    final values = parseEcgSignalCsv('0.1\n\n0.2\n   \n0.3');
    expect(values, [0.1, 0.2, 0.3]);
  });

  test('throws InvalidSignalFileException when nothing numeric is found', () {
    expect(
      () => parseEcgSignalCsv('not,a,number\nalso not one'),
      throwsA(isA<InvalidSignalFileException>()),
    );
  });
}
