import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/ecg_result.dart';
import 'auth_service.dart';

const _labelStyle = pw.TextStyle(fontSize: 9, color: PdfColors.grey600);
const _warnColor = PdfColor.fromInt(0xFFB23B22);

/// Builds the same content as ReportScreen, as a PDF — kept in its own
/// service (not inline in the screen) since it has nothing to do with
/// Flutter's widget tree: the `pdf` package's `pw.Widget` is a different,
/// unrelated widget system.
Future<Uint8List> buildReportPdf(EcgCase ecgCase) async {
  final doctor = AuthService.instance.currentUser;
  final logoBytes = await AuthService.instance.fetchLogoBytes();
  final m = ecgCase.measurements;

  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'CardioLens',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              if (logoBytes != null)
                pw.Image(pw.MemoryImage(logoBytes), height: 28)
              else if (doctor?.workplace != null)
                pw.Text(doctor!.workplace!, style: _labelStyle),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Divider(color: PdfColors.grey400),
          pw.SizedBox(height: 10),
          pw.Text('PATIENT', style: _labelStyle),
          pw.SizedBox(height: 2),
          pw.Text(
            ecgCase.patientLabel,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
          ),
          pw.Text(ecgCase.dateLabel, style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 6),
          pw.Text(
            '${ecgCase.sourceLabel} · ${ecgCase.leadLabel} · ${ecgCase.samplingRateHz} Hz · '
            'Filtre secteur ${ecgCase.powerlineFilterHz} Hz',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 14),
          pw.Text('MESURES', style: _labelStyle),
          pw.SizedBox(height: 4),
          _measurementRow('FC', '${m.heartRateBpm.round()} bpm'),
          _measurementRow('PR', '${m.prIntervalMs.round()} ms'),
          _measurementRow('QRS', '${m.qrsDurationMs.round()} ms', warn: m.qrsDurationMs > 120),
          _measurementRow(
            'QTc (Bazett)',
            '${m.qtcBazettMs.round()} ms',
            warn: m.qtcBazettMs > 450,
          ),
          _measurementRow('QTc (Fridericia)', '${m.qtcFridericiaMs.round()} ms'),
          pw.SizedBox(height: 14),
          pw.Text('INTERPRÉTATION (RÈGLES CLINIQUES)', style: _labelStyle),
          pw.SizedBox(height: 4),
          pw.Text(
            ecgCase.ruleAlerts.isEmpty
                ? 'Aucune anomalie détectée par les règles.'
                : ecgCase.ruleAlerts.map((a) => a.message).join('. '),
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 3),
          ),
          if (ecgCase.aiAlerts.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text('SIGNAL IA - A CORRÉLER CLINIQUEMENT', style: _labelStyle),
            pw.SizedBox(height: 4),
            for (final alert in ecgCase.aiAlerts)
              pw.Text(
                alert.confidence != null
                    ? '${alert.message} (confiance : ${(alert.confidence! * 100).round()}%)'
                    : alert.message,
                style: const pw.TextStyle(fontSize: 11, lineSpacing: 3),
              ),
          ],
          pw.SizedBox(height: 24),
          pw.Divider(color: PdfColors.grey400),
          pw.SizedBox(height: 8),
          pw.Text('VALIDÉ PAR', style: _labelStyle),
          pw.SizedBox(height: 2),
          pw.Text(
            doctor != null
                ? '${doctor.displayName} - en attente de validation'
                : '[Dr. Nom Prénom] - en attente de validation',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
          ),
          pw.Spacer(),
          pw.Divider(color: PdfColors.grey400),
          pw.Text(
            'CardioLens - aide à l\'interprétation ECG, ne remplace pas le jugement médical. '
            'Document à valider par un médecin avant toute décision clinique.',
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey500),
          ),
        ],
      ),
    ),
  );

  return doc.save();
}

pw.Widget _measurementRow(String label, String value, {bool warn = false}) {
  final color = warn ? _warnColor : PdfColors.black;
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 10.5, color: color)),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: color),
        ),
      ],
    ),
  );
}

/// A filesystem-safe filename derived from the patient label — free text
/// on screen, but a PDF filename can't contain path separators or most
/// punctuation.
String reportPdfFilename(EcgCase ecgCase) {
  final safeLabel = ecgCase.patientLabel
      .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return 'compte-rendu-${safeLabel.isEmpty ? "ecg" : safeLabel}.pdf';
}
