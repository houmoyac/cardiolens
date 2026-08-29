import 'package:cardiolens_app/data/sample_cases.dart';
import 'package:cardiolens_app/services/pdf_report.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds a non-empty PDF document for a sample case', () async {
    final bytes = await buildReportPdf(sampleCases.first);

    expect(bytes, isNotEmpty);
    // The PDF file signature — proves this is an actual PDF, not just any
    // non-empty byte list.
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('derives a filesystem-safe filename from the patient label', () {
    expect(reportPdfFilename(sampleCases.first), 'compte-rendu-Patient-A-2288.pdf');
  });
}
