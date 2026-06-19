import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/bill.dart';
import '../../../models/payment.dart';
import '../../../models/flat.dart';
import '../../../models/tenant.dart';
import '../../../services/bill_generator.dart';
import '../../../services/export_service.dart';
import '../../../shared/providers.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../payments/presentation/collect_payment_screen.dart';

class BillFormScreen extends ConsumerStatefulWidget {
  final Bill bill;
  const BillFormScreen({super.key, required this.bill});

  @override
  ConsumerState<BillFormScreen> createState() => _BillFormScreenState();
}

class _BillFormScreenState extends ConsumerState<BillFormScreen> {
  late TextEditingController _rentController;
  late TextEditingController _gasController;
  late TextEditingController _waterController;
  late TextEditingController _garageController;
  late TextEditingController _electricityController;
  late TextEditingController _currentReadingController;
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isDeleting = false;
  List<Payment> _payments = [];
  Tenant? _tenant;
  Flat? _flat;
  double _prevReading = 0;

  @override
  void initState() {
    super.initState();
    _rentController = TextEditingController(text: widget.bill.rent.toStringAsFixed(0));
    _gasController = TextEditingController(text: widget.bill.gas.toStringAsFixed(0));
    _waterController = TextEditingController(text: widget.bill.water.toStringAsFixed(0));
    _garageController = TextEditingController(text: widget.bill.garage.toStringAsFixed(0));
    _electricityController = TextEditingController(text: widget.bill.electricity.toStringAsFixed(0));
    _currentReadingController = TextEditingController(
      text: widget.bill.currentMeterReading > 0 ? widget.bill.currentMeterReading.toStringAsFixed(0) : '',
    );
    _prevReading = widget.bill.prevMeterReading;
    _loadData();
  }

  Future<void> _loadData() async {
    final service = ref.read(firestoreServiceProvider);
    final paymentsSnap = await service.getPaymentsByBill(widget.bill.id).first;

    DocumentSnapshot<Map<String, dynamic>>? tenantSnap;
    DocumentSnapshot<Map<String, dynamic>>? flatSnap;
    try {
      tenantSnap = await service.getTenantDoc(widget.bill.tenantId);
      flatSnap = await service.getFlatDoc(widget.bill.flatId);
    } catch (_) {}

    final p = paymentsSnap.docs
        .map((d) => Payment.fromMap(d.id, d.data()))
        .toList();

    if (mounted) {
      setState(() {
        _tenant = tenantSnap?.exists == true
            ? Tenant.fromMap(tenantSnap!.id, tenantSnap.data()!)
            : null;
        _flat = flatSnap?.exists == true
            ? Flat.fromMap(flatSnap!.id, flatSnap.data()!)
            : null;
        _payments = p;
      });
    }
  }

  @override
  void dispose() {
    _rentController.dispose();
    _gasController.dispose();
    _waterController.dispose();
    _garageController.dispose();
    _electricityController.dispose();
    _currentReadingController.dispose();
    super.dispose();
  }

  double get _calculatedElectricity {
    final current = double.tryParse(_currentReadingController.text.trim()) ?? 0;
    if (current > _prevReading && _flat != null) {
      return (current - _prevReading) * _flat!.unitRate;
    }
    return double.parse(_electricityController.text.trim());
  }

  String get _flatLabel {
    if (_flat == null) return '';
    final f = _flat!;
    if (f.floor.isNotEmpty) return '${f.floor} - ${f.flatNo}';
    return f.flatNo;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final currentReading = double.tryParse(_currentReadingController.text.trim()) ?? 0;
      double electricity;
      if (currentReading > _prevReading && _flat != null && _flat!.unitRate > 0) {
        electricity = (currentReading - _prevReading) * _flat!.unitRate;
      } else {
        electricity = double.parse(_electricityController.text.trim());
      }

      final updated = Bill(
        id: widget.bill.id,
        tenantId: widget.bill.tenantId,
        flatId: widget.bill.flatId,
        month: widget.bill.month,
        rent: double.parse(_rentController.text.trim()),
        gas: double.parse(_gasController.text.trim()),
        water: double.parse(_waterController.text.trim()),
        garage: double.parse(_garageController.text.trim()),
        electricity: electricity,
        prevMeterReading: _prevReading,
        currentMeterReading: currentReading,
        status: widget.bill.status,
        paidAmount: widget.bill.paidAmount,
      );

      await ref.read(firestoreServiceProvider).updateBill(widget.bill.id, updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('বিল আপডেট করা হয়েছে'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ত্রুটি: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteBill() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('নিশ্চিত করুন'),
        content: const Text('আপনি কি এই বিলটি মুছতে চান?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text(AppStrings.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text(AppStrings.delete)),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      await ref.read(firestoreServiceProvider).deleteBill(widget.bill.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('বিল মুছে ফেলা হয়েছে'), backgroundColor: AppColors.success),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ত্রুটি: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  Future<void> _deletePayment(Payment payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('নিশ্চিত করুন'),
        content: const Text('আপনি কি এই পেমেন্টটি মুছতে চান?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text(AppStrings.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text(AppStrings.delete)),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final service = ref.read(firestoreServiceProvider);
      await service.deletePayment(payment.id);

      final newPaid = widget.bill.paidAmount - payment.amount;
      final newStatus = newPaid <= 0 ? 'pending' : (newPaid >= widget.bill.total ? 'paid' : 'partial');
      final safePaid = newPaid < 0 ? 0 : newPaid;
      await service.updateBillPartial(widget.bill.id, {
        'paidAmount': safePaid,
        'status': newStatus,
      });

      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('পেমেন্ট মুছে ফেলা হয়েছে'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ত্রুটি: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _shareReceipt() async {
    final bill = widget.bill;
    if (bill.isPending) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('শুধুমাত্র পরিশোধিত বিলের রসিদ শেয়ার করা যাবে'), backgroundColor: AppColors.warning),
      );
      return;
    }

    final pdf = await ExportService.generateReceiptPdf(
      tenantName: _tenant?.name ?? '',
      flatNo: _flatLabel,
      month: BillGenerator.formatMonth(bill.month),
      items: [
        MapEntry(AppStrings.rent, bill.rent),
        MapEntry(AppStrings.gas, bill.gas),
        MapEntry(AppStrings.water, bill.water),
        MapEntry(AppStrings.garage, bill.garage),
        MapEntry(AppStrings.electricity, bill.electricity),
      ],
      total: bill.total,
      paid: bill.paidAmount,
      method: '',
      receiptNo: '${bill.month}-${bill.flatId.length > 4 ? bill.flatId.substring(0, 4) : bill.flatId}',
      date: DateTime.now().toString().substring(0, 10),
    );

    await ExportService.shareFile(pdf, 'receipt_${bill.id}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final bill = widget.bill;
    final auth = ref.read(authServiceProvider);
    final signatureName = auth.userName ?? 'ব্যবহারকারী';
    final showSignature = bill.isPaid || bill.isPartial;

    return Scaffold(
      appBar: AppBar(
        title: Text('${AppStrings.billDetails}: ${BillGenerator.formatMonth(bill.month)}'),
        actions: [
          if (showSignature)
            IconButton(
              icon: const Icon(Icons.share, color: Colors.green),
              tooltip: AppStrings.shareReceipt,
              onPressed: _shareReceipt,
            ),
          IconButton(
            icon: const Icon(Icons.delete, color: AppColors.error),
            onPressed: _isDeleting ? null : _deleteBill,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Header: Floor-Flat + Month + Tenant + Status
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Text(_flatLabel,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold, color: AppColors.primary)),
                      const SizedBox(height: 6),
                      Text(BillGenerator.formatMonth(bill.month),
                          style: Theme.of(context).textTheme.titleMedium),
                      if (_tenant != null) ...[
                        const SizedBox(height: 4),
                        Text(_tenant!.name,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      ],
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: StatusBadge(status: bill.status),
                      ),
                      // Meter readings
                      if (_flat != null && _flat!.unitRate > 0) ...[
                        const Divider(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: Text('পূর্ববর্তী রিডিং: ${_prevReading.toStringAsFixed(0)}',
                                  style: const TextStyle(fontSize: 13)),
                            ),
                            Expanded(
                              child: TextFormField(
                                controller: _currentReadingController,
                                decoration: const InputDecoration(
                                  labelText: AppStrings.currentReading,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                        if (_currentReadingController.text.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.bolt, size: 16, color: AppColors.warning),
                                const SizedBox(width: 6),
                                Text(
                                  '${AppStrings.electricity}: ৳${_calculatedElectricity.toStringAsFixed(0)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Bill breakdown table
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _BillRow(label: AppStrings.rent, amount: bill.rent),
                      const Divider(height: 10),
                      _BillRow(label: AppStrings.gas, amount: bill.gas),
                      const Divider(height: 10),
                      _BillRow(label: AppStrings.water, amount: bill.water),
                      const Divider(height: 10),
                      _BillRow(label: AppStrings.garage, amount: bill.garage),
                      const Divider(height: 10),
                      _BillRow(label: AppStrings.electricity, amount: bill.electricity),
                      const Divider(height: 10),
                      _BillRow(label: AppStrings.total, amount: bill.total,
                          isBold: true, color: AppColors.textPrimary),
                      const Divider(height: 10),
                      _BillRow(label: AppStrings.paidAmount, amount: bill.paidAmount,
                          color: AppColors.paidColor),
                      const Divider(height: 10),
                      _BillRow(label: AppStrings.due, amount: bill.due,
                          isBold: true, color: AppColors.pendingColor),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Edit amounts section
              ExpansionTile(
                title: const Text('পরিমাণ সম্পাদনা',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                children: [
                  _AmountField(label: AppStrings.rent, controller: _rentController),
                  const SizedBox(height: 8),
                  _AmountField(label: AppStrings.gas, controller: _gasController),
                  const SizedBox(height: 8),
                  _AmountField(label: AppStrings.water, controller: _waterController),
                  const SizedBox(height: 8),
                  _AmountField(label: AppStrings.garage, controller: _garageController),
                  const SizedBox(height: 8),
                  _AmountField(label: AppStrings.electricity, controller: _electricityController),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                          : const Text(AppStrings.save),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
              const SizedBox(height: 16),

              // Payments section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('পেমেন্ট', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text(AppStrings.collectPayment),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => CollectPaymentScreen(bill: bill)),
                      );
                      _loadData();
                    },
                  ),
                ],
              ),
              if (_payments.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('কোনো পেমেন্ট নেই', style: TextStyle(color: AppColors.textHint)),
                )
              else
                ...(_payments.map((p) => Card(
                      child: ListTile(
                        dense: true,
                        title: Text('৳${p.amount.toStringAsFixed(0)}'),
                        subtitle: Text('${p.method}  |  ${p.date.day}/${p.date.month}/${p.date.year}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                          onPressed: () => _deletePayment(p),
                        ),
                      ),
                    ))),
              const SizedBox(height: 16),

              // Electronic signature (only when paid/partial)
              if (showSignature)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.divider)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ইলেকট্রনিক স্বাক্ষর',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.edit_note, size: 18, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(signatureName,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmountField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  const _AmountField({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixText: '৳ ',
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      keyboardType: TextInputType.number,
      validator: (v) => v?.isEmpty ?? true ? 'মান দিন' : null,
    );
  }
}

class _BillRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isBold;
  final Color? color;
  const _BillRow({required this.label, required this.amount, this.isBold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: isBold ? const TextStyle(fontWeight: FontWeight.bold) : null),
        Text('৳${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: color,
            )),
      ],
    );
  }
}
