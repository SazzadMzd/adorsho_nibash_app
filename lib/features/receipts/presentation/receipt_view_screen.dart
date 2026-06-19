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

class ReceiptViewScreen extends ConsumerStatefulWidget {
  final Bill bill;
  const ReceiptViewScreen({super.key, required this.bill});

  @override
  ConsumerState<ReceiptViewScreen> createState() => _ReceiptViewScreenState();
}

class _ReceiptViewScreenState extends ConsumerState<ReceiptViewScreen> {
  Tenant? _tenant;
  Flat? _flat;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final service = ref.read(firestoreServiceProvider);
    try {
      final tenantSnap = await service.getTenantDoc(widget.bill.tenantId);
      final flatSnap = await service.getFlatDoc(widget.bill.flatId);
      if (mounted) {
        setState(() {
          _tenant = tenantSnap.exists ? Tenant.fromMap(tenantSnap.id, tenantSnap.data()!) : null;
          _flat = flatSnap.exists ? Flat.fromMap(flatSnap.id, flatSnap.data()!) : null;
        });
      }
    } catch (_) {}
  }

  String get _flatLabel {
    final flat = _flat;
    if (flat == null) return '';
    return flat.floor.isNotEmpty ? '${flat.floor} - ${flat.flatNo}' : flat.flatNo;
  }

  String get _receiptNo {
    final suffix = widget.bill.flatId.length > 4 ? widget.bill.flatId.substring(0, 4) : widget.bill.flatId;
    return '${widget.bill.month}-$suffix';
  }

  Future<void> _shareReceipt() async {
    setState(() => _isSharing = true);
    try {
      final pdf = await ExportService.generateReceiptPdf(
        tenantName: _tenant?.name ?? '',
        flatNo: _flatLabel,
        month: BillGenerator.formatMonth(widget.bill.month),
        items: [
          MapEntry(AppStrings.rent, widget.bill.rent),
          MapEntry(AppStrings.gas, widget.bill.gas),
          MapEntry(AppStrings.water, widget.bill.water),
          MapEntry(AppStrings.garage, widget.bill.garage),
          MapEntry(AppStrings.electricity, widget.bill.electricity),
        ],
        total: widget.bill.total,
        paid: widget.bill.paidAmount,
        method: '',
        receiptNo: _receiptNo,
        date: DateTime.now().toString().substring(0, 10),
      );
      await ExportService.shareFile(pdf, 'receipt_${widget.bill.id}.pdf');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bill = widget.bill;
    final hasReading = bill.currentMeterReading > 0 || bill.prevMeterReading > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.receipt),
        actions: [
          IconButton(
            onPressed: _isSharing ? null : _shareReceipt,
            icon: _isSharing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.share),
            tooltip: AppStrings.shareReceipt,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        AppStrings.appName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${AppStrings.receiptNo}: $_receiptNo'),
                        Text(DateTime.now().toString().substring(0, 10)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('${AppStrings.month}: ${BillGenerator.formatMonth(bill.month)}'),
                    if (_tenant != null) Text('${AppStrings.tenantName}: ${_tenant!.name}'),
                    if (_flatLabel.isNotEmpty) Text('${AppStrings.flatNo}: $_flatLabel'),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Chip(label: Text(bill.status)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _RowItem(label: AppStrings.rent, value: bill.rent),
                    const Divider(height: 10),
                    _RowItem(label: AppStrings.gas, value: bill.gas),
                    const Divider(height: 10),
                    _RowItem(label: AppStrings.water, value: bill.water),
                    const Divider(height: 10),
                    _RowItem(label: AppStrings.garage, value: bill.garage),
                    const Divider(height: 10),
                    _RowItem(label: AppStrings.electricity, value: bill.electricity),
                    const Divider(height: 10),
                    _RowItem(label: AppStrings.total, value: bill.total, bold: true),
                    const Divider(height: 10),
                    _RowItem(label: AppStrings.paidAmount, value: bill.paidAmount),
                    const Divider(height: 10),
                    _RowItem(label: AppStrings.due, value: bill.due, bold: true, color: AppColors.pendingColor),
                  ],
                ),
              ),
            ),
            if (hasReading) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${AppStrings.prevReading}: ${bill.prevMeterReading.toStringAsFixed(0)}'),
                      const SizedBox(height: 4),
                      Text('${AppStrings.currentReading}: ${bill.currentMeterReading.toStringAsFixed(0)}'),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.divider),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'স্বাক্ষর',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 18),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text('________________'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RowItem extends StatelessWidget {
  final String label;
  final double value;
  final bool bold;
  final Color? color;
  const _RowItem({
    required this.label,
    required this.value,
    this.bold = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null),
        Text(
          '৳${value.toStringAsFixed(0)}',
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}
