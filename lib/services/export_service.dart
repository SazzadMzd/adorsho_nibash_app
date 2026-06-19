import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html_to_pdf/flutter_html_to_pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExportService {
  static Future<Map<String, String>>? _fontPathsFuture;

  static Future<Map<String, String>> _fontPaths() {
    return _fontPathsFuture ??= _loadFontPaths();
  }

  static Future<Map<String, String>> _loadFontPaths() async {
    final tempDir = await getTemporaryDirectory();
    final fontDir = Directory(tempDir.path);
    if (!await fontDir.exists()) {
      await fontDir.create(recursive: true);
    }

    final regularPath = '${fontDir.path}/NotoSerifBengali-Regular.ttf';
    final boldPath = '${fontDir.path}/NotoSerifBengali-Bold.ttf';

    if (!await File(regularPath).exists()) {
      final bytes = await rootBundle.load('assets/fonts/NotoSerifBengali-Regular.ttf');
      await File(regularPath).writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    }
    if (!await File(boldPath).exists()) {
      final bytes = await rootBundle.load('assets/fonts/NotoSerifBengali-Bold.ttf');
      await File(boldPath).writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    }

    return {
      'dir': fontDir.path,
      'regular': regularPath,
      'bold': boldPath,
    };
  }

  static String _escapeHtml(String value) => const HtmlEscape(HtmlEscapeMode.element).convert(value);

  static String _money(num value) => '৳ ${value.toStringAsFixed(0)}';

  static Future<Uint8List> _htmlToPdfBytes(String html, String filenameBase) async {
    final fonts = await _fontPaths();
    final file = await FlutterHtmlToPdf.convertFromHtmlContent(
      html,
      fonts['dir']!,
      filenameBase,
    );
    return file.readAsBytes();
  }

  static Future<String> _fontCss() async {
    await _fontPaths();
    const regular = 'NotoSerifBengali-Regular.ttf';
    const bold = 'NotoSerifBengali-Bold.ttf';
    return '''
@font-face {
  font-family: 'NotoSerifBengali';
  src: url('$regular') format('truetype');
  font-weight: 400;
  font-style: normal;
}
@font-face {
  font-family: 'NotoSerifBengali';
  src: url('$bold') format('truetype');
  font-weight: 700;
  font-style: normal;
}
''';
  }

  static String _buildReceiptHtml({
    required String fontCss,
    required String tenantName,
    required String flatNo,
    required String month,
    required List<MapEntry<String, double>> items,
    required double total,
    required double paid,
    required String method,
    required String date,
    String prevReadingLabel = '',
    String currentReadingLabel = '',
  }) {
    final receiptItems = items.map((item) {
      final isElectricity = item.key.trim() == 'বিদ্যুৎ';
      final readingHtml = isElectricity &&
              (prevReadingLabel.isNotEmpty || currentReadingLabel.isNotEmpty)
          ? '''
          <div class="reading-block">
            ${prevReadingLabel.isNotEmpty ? '<div>আগের রিডিং: ${_escapeHtml(prevReadingLabel)}</div>' : ''}
            ${currentReadingLabel.isNotEmpty ? '<div>বর্তমান রিডিং: ${_escapeHtml(currentReadingLabel)}</div>' : ''}
          </div>
        '''
          : '';
      return '''
        <div class="bill-row">
          <div class="label-wrap">
            <span>${_escapeHtml(item.key)}</span>
            $readingHtml
          </div>
          <div class="amount">${_money(item.value)}</div>
        </div>
      ''';
    }).join();

    final methodHtml = method.isNotEmpty
        ? '<div class="meta-row"><span>পরিশোধের মাধ্যম:</span><span>${_escapeHtml(method)}</span></div>'
        : '';

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    $fontCss
  </style>
  <style>
    body {
      font-family: 'NotoSerifBengali', sans-serif;
      color: #111;
      margin: 0;
      padding: 0;
      font-size: 14px;
      line-height: 1.45;
    }
    .page {
      padding: 28px 24px 24px;
    }
    .title {
      text-align: center;
      font-size: 22px;
      font-weight: 700;
      margin: 0 0 18px;
    }
    .meta-row {
      display: flex;
      justify-content: space-between;
      gap: 12px;
      margin-bottom: 8px;
    }
    .meta-row strong {
      font-weight: 700;
    }
    .section {
      margin-top: 14px;
      border-top: 1px solid #222;
      border-bottom: 1px solid #222;
      padding: 8px 0;
    }
    .bill-row {
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      gap: 12px;
      padding: 8px 0;
      border-bottom: 1px solid #ececec;
    }
    .bill-row:last-child {
      border-bottom: 0;
    }
    .label-wrap {
      flex: 1;
      min-width: 0;
      padding-right: 10px;
    }
    .reading-block {
      margin-top: 4px;
      margin-left: 10px;
      color: #444;
      font-size: 12px;
      line-height: 1.35;
    }
    .amount {
      flex: 0 0 auto;
      white-space: nowrap;
      font-weight: 500;
    }
    .totals {
      margin-top: 10px;
    }
    .totals .bill-row {
      border-bottom: 0;
      padding: 5px 0;
    }
    .totals .total {
      font-weight: 700;
      font-size: 15px;
    }
    .totals .due {
      color: #b3261e;
      font-weight: 700;
    }
    .signature {
      margin-top: 18px;
      display: flex;
      justify-content: flex-end;
    }
    .signature-box {
      width: 160px;
      text-align: right;
    }
    .signature-line {
      margin-top: 18px;
      border-top: 1px solid #111;
      width: 100%;
    }
  </style>
</head>
<body>
  <div class="page">
    <h1 class="title">রসিদ / RECEIPT</h1>
    <div class="meta-row"><span>তারিখ: ${_escapeHtml(date)}</span><span></span></div>
    <div class="meta-row"><span>ভাড়াটিয়া: ${_escapeHtml(tenantName)}</span><span></span></div>
    <div class="meta-row"><span>ফ্ল্যাট নং: ${_escapeHtml(flatNo)}</span><span></span></div>
    <div class="meta-row"><span>মাস: ${_escapeHtml(month)}</span><span></span></div>

    <div class="section">
      $receiptItems
    </div>

    <div class="totals">
      <div class="bill-row total">
        <div>মোট</div>
        <div class="amount">${_money(total)}</div>
      </div>
      <div class="bill-row">
        <div>পরিশোধিত</div>
        <div class="amount">${_money(paid)}</div>
      </div>
      <div class="bill-row due">
        <div>বকেয়া</div>
        <div class="amount">${_money(total - paid)}</div>
      </div>
      $methodHtml
    </div>

    <div class="signature">
      <div class="signature-box">
        <div>স্বাক্ষর</div>
        <div class="signature-line"></div>
      </div>
    </div>
  </div>
</body>
</html>
''';
  }

  static String _buildReportHtml({
    required String fontCss,
    required String title,
    required String period,
    required List<List<String>> rows,
    required List<String> headers,
  }) {
    final headerHtml = headers
        .map((h) => '<th>${_escapeHtml(h)}</th>')
        .join();
    final rowHtml = rows.map((row) {
      final cells = List.generate(headers.length, (index) {
        final value = index < row.length ? row[index] : '';
        final isSummary = value == 'সারসংক্ষেপ';
        return '<td class="${isSummary ? 'summary-label' : ''}">${_escapeHtml(value)}</td>';
      }).join();
      final isSummaryRow = row.isNotEmpty && row.first == 'সারসংক্ষেপ';
      return '<tr class="${isSummaryRow ? 'summary-row' : ''}">$cells</tr>';
    }).join();

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    $fontCss
  </style>
  <style>
    body {
      font-family: 'NotoSerifBengali', sans-serif;
      color: #111;
      margin: 0;
      padding: 0;
      font-size: 14px;
    }
    .page {
      padding: 28px 24px;
    }
    .company {
      text-align: center;
      font-size: 20px;
      font-weight: 700;
      margin-bottom: 4px;
    }
    .title {
      text-align: center;
      font-size: 16px;
      font-weight: 700;
      margin-bottom: 6px;
    }
    .period {
      text-align: center;
      margin-bottom: 16px;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      font-size: 13px;
    }
    th, td {
      border: 1px solid #222;
      padding: 7px 6px;
      text-align: right;
      vertical-align: top;
    }
    th {
      background: #f2f2f2;
      font-weight: 700;
    }
    th:first-child, td:first-child {
      text-align: left;
    }
    tr.summary-row td {
      font-weight: 700;
      background: #fafafa;
    }
    td.summary-label {
      text-align: left;
    }
  </style>
</head>
<body>
  <div class="page">
    <div class="company">আদর্শ নিবাস (মজুমদার)</div>
    <div class="title">${_escapeHtml(title)}</div>
    <div class="period">সময়: ${_escapeHtml(period)}</div>
    <table>
      <thead>
        <tr>$headerHtml</tr>
      </thead>
      <tbody>
        $rowHtml
      </tbody>
    </table>
  </div>
</body>
</html>
''';
  }

  static Future<Uint8List> generateReceiptPdf({
    required String tenantName,
    required String flatNo,
    required String month,
    required List<MapEntry<String, double>> items,
    required double total,
    required double paid,
    required String method,
    required String date,
    String prevReadingLabel = '',
    String currentReadingLabel = '',
  }) async {
    final fontCss = await _fontCss();
    final html = _buildReceiptHtml(
      fontCss: fontCss,
      tenantName: tenantName,
      flatNo: flatNo,
      month: month,
      items: items,
      total: total,
      paid: paid,
      method: method,
      date: date,
      prevReadingLabel: prevReadingLabel,
      currentReadingLabel: currentReadingLabel,
    );
    return _htmlToPdfBytes(html, 'receipt_${DateTime.now().millisecondsSinceEpoch}');
  }

  static Future<Uint8List> generateReportPdf({
    required String title,
    required String period,
    required List<List<String>> rows,
    required List<String> headers,
  }) async {
    final fontCss = await _fontCss();
    final html = _buildReportHtml(
      fontCss: fontCss,
      title: title,
      period: period,
      rows: rows,
      headers: headers,
    );
    return _htmlToPdfBytes(html, 'report_${DateTime.now().millisecondsSinceEpoch}');
  }

  static Future<void> shareFile(Uint8List bytes, String filename) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
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
