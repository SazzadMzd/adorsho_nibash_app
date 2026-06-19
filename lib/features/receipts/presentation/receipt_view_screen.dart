import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/bill.dart';
import '../../../models/flat.dart';
import '../../../models/tenant.dart';
import '../../../models/payment.dart';
import '../../../services/bill_generator.dart';
import '../../../services/export_service.dart';
import '../../../shared/providers.dart';
import '../../../shared/widgets/animations.dart';

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
  bool _isDeleting = false;
  List<Payment> _payments = [];

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
      final paymentsSnap = await service.getPaymentsByBill(widget.bill.id).first;
      if (mounted) {
        setState(() {
          _tenant = tenantSnap.exists ? Tenant.fromMap(tenantSnap.id, tenantSnap.data()!) : null;
          _flat = flatSnap.exists ? Flat.fromMap(flatSnap.id, flatSnap.data()!) : null;
          _payments = paymentsSnap.docs
              .map((d) => Payment.fromMap(d.id, d.data()))
              .toList();
        });
      }
    } catch (_) {}
  }

  String get _paymentDate {
    if (_payments.isEmpty) return widget.bill.createdAt.toIso8601String().substring(0, 10);
    final lastPayment = _payments.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
    return '${lastPayment.date.day}/${lastPayment.date.month}/${lastPayment.date.year}';
  }

  String get _flatLabel {
    final flat = _flat;
    if (flat == null) return '';
    return flat.floor.isNotEmpty ? '${flat.floor} - ${flat.flatNo}' : flat.flatNo;
  }

  Future<void> _shareReceipt() async {
    setState(() => _isSharing = true);
    try {
      final auth = ref.read(authServiceProvider);
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
        method: _payments.isNotEmpty ? _payments.last.method : '',
        date: _paymentDate,
        signatureName: widget.bill.signedBy.isNotEmpty
            ? widget.bill.signedBy
            : auth.currentDisplayName(),
        prevReadingLabel: widget.bill.prevMeterReading > 0
            ? widget.bill.prevMeterReading.toStringAsFixed(0)
            : '',
        currentReadingLabel: widget.bill.currentMeterReading > 0
            ? widget.bill.currentMeterReading.toStringAsFixed(0)
            : '',
      );
      await ExportService.shareFile(pdf, 'receipt_${widget.bill.id}.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('রসিদ শেয়ার করা যায়নি: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _deleteBill() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('নিশ্চিত করুন'),
        content: const Text('আপনি কি এই বিলটি মুছতে চান?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      await ref.read(firestoreServiceProvider).deleteBill(widget.bill.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('বিল মুছে ফেলা হয়েছে'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ত্রুটি: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bill = widget.bill;
    final auth = ref.read(authServiceProvider);
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
          if (auth.isAdmin)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: _isDeleting ? null : _deleteBill,
              tooltip: AppStrings.delete,
            ),
        ],
      ),
      body: AnimatedPageEntrance(
        slideOffset: 16,
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_paymentDate),
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
                    if (hasReading) ...[
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${AppStrings.prevReading}: ${bill.prevMeterReading.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 12)),
                            Text('${AppStrings.currentReading}: ${bill.currentMeterReading.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
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
          ],
        ),
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
