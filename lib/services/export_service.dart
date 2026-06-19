import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExportService {
  static Future<pw.ThemeData>? _banglaThemeFuture;

  static Future<pw.ThemeData> _banglaTheme() {
    return _banglaThemeFuture ??= _loadBanglaTheme();
  }

  static Future<pw.ThemeData> _loadBanglaTheme() async {
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansBengali-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansBengali-Bold.ttf'),
    );
    return pw.ThemeData.withFont(base: regular, bold: bold);
  }

  static Future<Uint8List> generateReceiptPdf({
    required String tenantName,
    required String flatNo,
    required String month,
    required List<MapEntry<String, double>> items,
    required double total,
    required double paid,
    required String method,
    required String receiptNo,
    required String date,
  }) async {
    final pdf = pw.Document();
    final theme = await _banglaTheme();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a6,
        theme: theme,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Header(
              level: 0,
              child: pw.Text(
                'আদর্শ নিবাস (মজুমদার)',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Center(child: pw.Text('রসিদ / RECEIPT')),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('রসিদ নং: $receiptNo'),
                pw.Text('তারিখ: $date'),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Text('ভাড়াটিয়া: $tenantName'),
            pw.Text('ফ্ল্যাট নং: $flatNo'),
            pw.Text('মাস: $month'),
            pw.SizedBox(height: 8),
            pw.Divider(),
            ...items.map(
              (e) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 3),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(child: pw.Text(e.key)),
                    pw.Text('৳ ${e.value.toStringAsFixed(0)}'),
                  ],
                ),
              ),
            ),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('মোট',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('৳ ${total.toStringAsFixed(0)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('পরিশোধিত:'),
                pw.Text('৳ ${paid.toStringAsFixed(0)}'),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('বকেয়া:'),
                pw.Text('৳ ${(total - paid).toStringAsFixed(0)}'),
              ],
            ),
            pw.SizedBox(height: 8),
            if (method.isNotEmpty) pw.Text('পরিশোধের মাধ্যম: $method'),
            pw.SizedBox(height: 16),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('স্বাক্ষর'),
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> generateReportPdf({
    required String title,
    required String period,
    required List<List<String>> rows,
    required List<String> headers,
  }) async {
    final pdf = pw.Document();
    final theme = await _banglaTheme();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        build: (context) => pw.Column(
          children: [
            pw.Header(level: 0, child: pw.Text('আদর্শ নিবাস (মজুমদার)')),
            pw.Header(level: 1, child: pw.Text(title)),
            pw.Text('সময়: $period'),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: rows,
              border: pw.TableBorder.all(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  static Future<void> shareFile(Uint8List bytes, String filename) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)]);
  }

  static Future<List<int>> generateExcel({
    required String title,
    required List<String> headers,
    required List<List<dynamic>> data,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Report'];

    sheet.appendRow([TextCellValue(title)]);
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
    for (final row in data) {
      sheet.appendRow(row.map((c) {
        if (c is String) return TextCellValue(c);
        if (c is num) return DoubleCellValue(c.toDouble());
        return TextCellValue(c.toString());
      }).toList());
    }

    return excel.encode()!;
  }
}
