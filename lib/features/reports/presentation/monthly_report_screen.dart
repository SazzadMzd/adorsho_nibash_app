import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/bill.dart';
import '../../../models/flat.dart';
import '../../../models/tenant.dart';
import '../../../services/bill_generator.dart';
import '../../../services/export_service.dart';
import '../../../shared/providers.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../bills/presentation/bill_form_screen.dart';

class MonthlyReportScreen extends ConsumerStatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  ConsumerState<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends ConsumerState<MonthlyReportScreen> {
  late int _year;
  late int _month;
  List<Bill> _bills = [];
  Map<String, Tenant> _tenantMap = {};
  Map<String, Flat> _flatMap = {};
  Map<String, DateTime> _paymentDates = {};
  bool _isLoading = false;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    _loadData();
  }

  String get _monthStr => '$_year-${_month.toString().padLeft(2, '0')}';

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final service = ref.read(firestoreServiceProvider);
      final snap = await service.getMonthBillsSnapshot(_monthStr);

      final tenantsSnap = await service.getAllTenants().first;
      final flatsSnap = await service.getFlats().first;

      final tMap = {for (final d in tenantsSnap.docs)
        d.id: Tenant.fromMap(d.id, d.data())};
      final fMap = {for (final d in flatsSnap.docs)
        d.id: Flat.fromMap(d.id, d.data())};

      final bills = snap.docs.map((d) => Bill.fromMap(d.id, d.data())).toList();
      final billIds = bills.map((b) => b.id).toList();
      final paymentsByBill = await service.getPaymentsByBillIds(billIds);
      final paymentDates = <String, DateTime>{};
      for (final entry in paymentsByBill.entries) {
        if (entry.value.isNotEmpty) {
          entry.value.sort((a, b) => b.date.compareTo(a.date));
          paymentDates[entry.key] = entry.value.first.date;
        }
      }

      if (mounted) {
        setState(() {
          _bills = bills;
          _bills.sort((a, b) => a.flatId.compareTo(b.flatId));
          _tenantMap = tMap;
          _flatMap = fMap;
          _paymentDates = paymentDates;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _previousMonth() {
    setState(() {
      _month--;
      if (_month < 1) {
        _month = 12;
        _year--;
      }
    });
    _loadData();
  }

  void _nextMonth() {
    setState(() {
      _month++;
      if (_month > 12) {
        _month = 1;
        _year++;
      }
    });
    _loadData();
  }

  String _flatLabel(Flat? f) {
    if (f == null) return '';
    return f.floor.isNotEmpty ? '${f.floor} - ${f.flatNo}' : f.flatNo;
  }

  String _paymentDate(Bill bill) {
    final pd = _paymentDates[bill.id];
    if (pd != null) {
      return '${pd.day}/${pd.month}/${pd.year}';
    }
    return '${bill.createdAt.day}/${bill.createdAt.month}/${bill.createdAt.year}';
  }

  Future<void> _exportPdf() async {
    setState(() => _isExporting = true);
    try {
      final receipts = _bills.map((bill) {
        final tenant = _tenantMap[bill.tenantId];
        final flat = _flatMap[bill.flatId];
        return ReceiptSheetEntry(
          tenantName: tenant?.name ?? '',
          flatNo: _flatLabel(flat),
          month: BillGenerator.formatMonth(bill.month),
          date: _paymentDate(bill),
          items: [
            MapEntry(AppStrings.rent, bill.rent),
            MapEntry(AppStrings.gas, bill.gas),
            MapEntry(AppStrings.water, bill.water),
            MapEntry(AppStrings.garage, bill.garage),
            MapEntry(AppStrings.electricity, bill.electricity),
          ],
          total: bill.total,
          paid: bill.paidAmount,
          signatureName: bill.isPaid ? bill.signedBy : '',
          prevReadingLabel: bill.prevMeterReading > 0 ? bill.prevMeterReading.toStringAsFixed(0) : '',
          currentReadingLabel: bill.currentMeterReading > 0 ? bill.currentMeterReading.toStringAsFixed(0) : '',
        );
      }).toList();

      final pdf = await ExportService.generateMonthlyReceiptsPdf(
        title: 'মাসিক প্রতিবেদন',
        period: BillGenerator.formatMonth(_monthStr),
        receipts: receipts,
      );
      await ExportService.shareFile(pdf, 'report_$_monthStr.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ত্রুটি: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportExcel() async {
    setState(() => _isExporting = true);
    try {
      final headers = ['ফ্ল্যাট', 'ভাড়াটিয়া', 'মাস', 'ভাড়া', 'গ্যাস', 'পানি', 'গ্যারেজ', 'বিদ্যুৎ',
          'মোট', 'পরিশোধিত', 'বকেয়া', 'স্ট্যাটাস', 'প্রদানের তারিখ'];
      final data = _bills.map((b) {
        final tenant = _tenantMap[b.tenantId];
        final flat = _flatMap[b.flatId];
        return [
          _flatLabel(flat),
          tenant?.name ?? '',
          _monthStr,
          b.rent,
          b.gas,
          b.water,
          b.garage,
          b.electricity,
          b.total,
          b.paidAmount,
          b.due,
          b.status == 'paid' ? 'পরিশোধিত' : (b.status == 'partial' ? 'আংশিক' : 'বকেয়া'),
          _paymentDate(b),
        ] as List<dynamic>;
      }).toList();

      // Summary row
      data.add([
        'সারসংক্ষেপ', '', '', '',
        _bills.fold<double>(0, (s, b) => s + b.rent),
        _bills.fold<double>(0, (s, b) => s + b.gas),
        _bills.fold<double>(0, (s, b) => s + b.water),
        _bills.fold<double>(0, (s, b) => s + b.garage),
        _bills.fold<double>(0, (s, b) => s + b.electricity),
        _bills.fold<double>(0, (s, b) => s + b.total),
        _bills.fold<double>(0, (s, b) => s + b.paidAmount),
        _bills.fold<double>(0, (s, b) => s + b.due),
        '',
        '',
      ]);

      final excelBytes = await ExportService.generateExcel(
        title: 'মাসিক প্রতিবেদন',
        headers: headers,
        data: data,
      );
      await ExportService.shareFile(Uint8List.fromList(excelBytes), 'report_$_monthStr.xlsx');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ত্রুটি: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalAmount = _bills.fold<double>(0, (s, b) => s + b.total);
    final totalPaid = _bills.fold<double>(0, (s, b) => s + b.paidAmount);
    final totalDue = _bills.fold<double>(0, (s, b) => s + b.due);
    final paidCount = _bills.where((b) => b.isPaid).length;
    final pendingCount = _bills.where((b) => b.isPending).length;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.monthlyReport)),
      body: Column(
        children: [
          // Month picker
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.background,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _isLoading ? null : _previousMonth,
                ),
                Text(
                  BillGenerator.formatMonth(_monthStr),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _isLoading ? null : _nextMonth,
                ),
              ],
            ),
          ),

          // Summary cards
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _SummaryChip(label: 'মোট', amount: totalAmount, color: AppColors.textPrimary),
                const SizedBox(width: 8),
                _SummaryChip(label: 'আদায়', amount: totalPaid, color: AppColors.paidColor),
                const SizedBox(width: 8),
                _SummaryChip(label: 'বকেয়া', amount: totalDue, color: AppColors.pendingColor),
              ],
            ),
          ),

          // Status summary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DefaultTextStyle(
              style: const TextStyle(fontSize: 13),
              child: Row(
                children: [
                  Text('মোট বিল: ${_bills.length}  |  '),
                  Text('পরিশোধিত: $paidCount', style: const TextStyle(color: AppColors.paidColor)),
                  Text('  |  '),
                  Text('বকেয়া: $pendingCount', style: const TextStyle(color: AppColors.pendingColor)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Bill list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _bills.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.receipt_long, size: 48, color: AppColors.textHint),
                            const SizedBox(height: 8),
                            const Text(AppStrings.noBills, style: TextStyle(color: AppColors.textHint)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _bills.length,
                        itemBuilder: (_, i) {
                          final bill = _bills[i];
                          final tenant = _tenantMap[bill.tenantId];
                          final flat = _flatMap[bill.flatId];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                            child: ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor: AppColors.primaryLight.withValues(alpha: 0.2),
                                child: Text('${i + 1}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                              title: Text(
                                '${_flatLabel(flat)}  ${tenant?.name ?? ''}',
                                style: const TextStyle(fontSize: 13),
                              ),
                              subtitle: Text('মোট: ৳${bill.total.toStringAsFixed(0)}  |  বকেয়া: ৳${bill.due.toStringAsFixed(0)}${bill.isPending ? '' : '  |  প্রদানের তারিখ: ${_paymentDate(bill)}'}',
                                  style: const TextStyle(fontSize: 11)),
                              trailing: StatusBadge(status: bill.status, fontSize: 10),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BillFormScreen(bill: bill, updateOnly: true),
                                  ),
                                );
                                _loadData();
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: _bills.isEmpty
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'pdf',
                  onPressed: _isExporting ? null : _exportPdf,
                  backgroundColor: AppColors.pendingColor,
                  child: const Icon(Icons.picture_as_pdf, color: Colors.white),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'excel',
                  onPressed: _isExporting ? null : _exportExcel,
                  backgroundColor: AppColors.paidColor,
                  child: const Icon(Icons.table_chart, color: Colors.white),
                ),
              ],
            ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  const _SummaryChip({required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text('৳${amount.toStringAsFixed(0)}',
                style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }
}
