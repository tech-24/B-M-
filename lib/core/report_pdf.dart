import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/models.dart';

/// Builds a printable PDF summary for [report] over the given period.
///
/// [isArabic] flips text direction to RTL and uses an Arabic-capable font
/// (fetched once via PdfGoogleFonts, then reused for the whole document).
/// [logoBytes] is the project's logo image (PNG/JPEG), if one is set.
Future<Uint8List> buildPeriodReportPdf({
  required String projectName,
  required String periodLabel,
  required String generatedOnLabel,
  required PeriodReport report,
  required bool isArabic,
  required String Function(double) money,
  required Map<String, String> labels,
  Uint8List? logoBytes,
  List<InventoryBreakdownRow> inventoryRows = const [],
}) async {
  final doc = pw.Document();

  final baseFont = isArabic
      ? await PdfGoogleFonts.notoNaskhArabicRegular()
      : await PdfGoogleFonts.notoSansRegular();
  final boldFont = isArabic
      ? await PdfGoogleFonts.notoNaskhArabicBold()
      : await PdfGoogleFonts.notoSansBold();

  final textDirection = isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr;
  final crossAlign =
      isArabic ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start;

  const primary = PdfColor.fromInt(0xFF146E82);
  const good = PdfColor.fromInt(0xFF2E9E6B);
  const bad = PdfColor.fromInt(0xFFD64545);
  const goodLight = PdfColor.fromInt(0xFFE7F5EF);
  const badLight = PdfColor.fromInt(0xFFFBEAEA);
  const grey = PdfColor.fromInt(0xFF6B7280);

  pw.Widget row(String label, double value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  font: bold ? boldFont : baseFont,
                  fontSize: bold ? 13 : 11.5,
                  color: grey)),
          pw.Text(money(value),
              style: pw.TextStyle(
                  font: bold ? boldFont : baseFont,
                  fontSize: bold ? 13 : 11.5)),
        ],
      ),
    );
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      textDirection: textDirection,
      margin: const pw.EdgeInsets.all(32),
      footer: (context) => pw.Column(children: [
        pw.Divider(color: PdfColors.grey200),
        pw.SizedBox(height: 6),
        pw.Text(generatedOnLabel,
            style: pw.TextStyle(font: baseFont, fontSize: 9, color: grey)),
      ]),
      build: (context) => [
        // Header: logo + project name + period
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Column(
              crossAxisAlignment: crossAlign,
              children: [
                pw.Text(projectName,
                    style: pw.TextStyle(
                        font: boldFont, fontSize: 20, color: primary)),
                pw.SizedBox(height: 4),
                pw.Text(periodLabel,
                    style:
                        pw.TextStyle(font: baseFont, fontSize: 12, color: grey)),
              ],
            ),
            if (logoBytes != null)
              pw.Container(
                width: 56,
                height: 56,
                decoration: pw.BoxDecoration(
                  borderRadius: pw.BorderRadius.circular(10),
                  image: pw.DecorationImage(
                    image: pw.MemoryImage(logoBytes),
                    fit: pw.BoxFit.cover,
                  ),
                ),
              ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 18),

        // Net profit hero
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: report.netProfit >= 0 ? goodLight : badLight,
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: crossAlign,
                children: [
                  pw.Text(labels['netProfit']!,
                      style: pw.TextStyle(
                          font: baseFont, fontSize: 11, color: grey)),
                  pw.SizedBox(height: 4),
                  pw.Text(money(report.netProfit),
                      style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 22,
                          color: report.netProfit >= 0 ? good : bad)),
                ],
              ),
              pw.Text('${report.profitPercent.toStringAsFixed(1)}%',
                  style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 16,
                      color: report.netProfit >= 0 ? good : bad)),
            ],
          ),
        ),
        pw.SizedBox(height: 22),

        // Breakdown
        pw.Text(labels['breakdown']!,
            style: pw.TextStyle(font: boldFont, fontSize: 14, color: primary)),
        pw.SizedBox(height: 6),
        row(labels['totalRevenue']!, report.totalSales, bold: true),
        pw.Divider(color: PdfColors.grey200),
        row(labels['productCost']!, report.productCost),
        row(labels['inventoryConsumption']!, report.inventoryConsumption),
        row(labels['dailyExpenses']!, report.dailyExpenses),
        row(labels['fixedExpenses']!, report.fixedExpenses),
        pw.Divider(color: PdfColors.grey300, thickness: 1),
        row(labels['netProfit']!, report.netProfit, bold: true),

        if (inventoryRows.isNotEmpty) ...[
          pw.SizedBox(height: 26),
          pw.Text(labels['inventoryBreakdown'] ?? '',
              style:
                  pw.TextStyle(font: boldFont, fontSize: 14, color: primary)),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder(
                horizontalInside: const pw.BorderSide(
                    color: PdfColors.grey200, width: 0.5)),
            columnWidths: const {
              0: pw.FlexColumnWidth(2.2),
              1: pw.FlexColumnWidth(1.3),
              2: pw.FlexColumnWidth(1.5),
              3: pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(children: [
                pw.Text(labels['itemName'] ?? '',
                    style: pw.TextStyle(font: boldFont, fontSize: 10.5)),
                pw.Text(labels['consumedQty'] ?? '',
                    style: pw.TextStyle(font: boldFont, fontSize: 10.5),
                    textAlign: pw.TextAlign.center),
                pw.Text(labels['productCost'] ?? '',
                    style: pw.TextStyle(font: boldFont, fontSize: 10.5),
                    textAlign: pw.TextAlign.center),
                pw.Text(labels['remainingNow'] ?? '',
                    style: pw.TextStyle(font: boldFont, fontSize: 10.5),
                    textAlign: pw.TextAlign.center),
              ]),
              for (final r in inventoryRows)
                pw.TableRow(children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 5),
                    child: pw.Text(r.name,
                        style: pw.TextStyle(font: baseFont, fontSize: 10)),
                  ),
                  pw.Text('${r.consumedQty.toStringAsFixed(1)} ${r.unit}',
                      style: pw.TextStyle(font: baseFont, fontSize: 10),
                      textAlign: pw.TextAlign.center),
                  pw.Text(money(r.cost),
                      style: pw.TextStyle(font: baseFont, fontSize: 10),
                      textAlign: pw.TextAlign.center),
                  pw.Text('${r.remainingNow.toStringAsFixed(1)} ${r.unit}',
                      style: pw.TextStyle(font: baseFont, fontSize: 10),
                      textAlign: pw.TextAlign.center),
                ]),
            ],
          ),
        ],
      ],
    ),
  );

  return doc.save();
}
