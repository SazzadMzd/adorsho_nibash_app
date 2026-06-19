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
  final bool updateOnly;
  const BillFormScreen({
    super.key,
    required this.bill,
    this.updateOnly = false,
  });

  @override
  ConsumerState<BillFormScreen> createState() => _BillFormScreenState();
}

class _BillFormScreenState extends ConsumerState<BillFormScreen> {
  late Bill _bill;
  late TextEditingController _rentController;
  late TextEditingController _gasController;
  late TextEditingController _waterController;
  late TextEditingController _garageController;
  late TextEditingController _electricityController;
  late TextEditingController _previousReadingController;
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
    _bill = widget.bill;
    _rentController = TextEditingController(
      text: _bill.rent.toStringAsFixed(0),
    );
    _gasController = TextEditingController(
      text: _bill.gas.toStringAsFixed(0),
    );
    _waterController = TextEditingController(
      text: _bill.water.toStringAsFixed(0),
    );
    _garageController = TextEditingController(
      text: _bill.garage.toStringAsFixed(0),
    );
    _electricityController = TextEditingController(
      text: _bill.electricity.toStringAsFixed(0),
    );
    _previousReadingController = TextEditingController(
      text: _bill.prevMeterReading > 0
          ? _bill.prevMeterReading.toStringAsFixed(0)
          : '',
    );
    _currentReadingController = TextEditingController(
      text: _bill.currentMeterReading > 0
          ? _bill.currentMeterReading.toStringAsFixed(0)
          : '',
    );
    _prevReading = _bill.prevMeterReading;
    _loadData();
  }

  Future<void> _loadData() async {
    final service = ref.read(firestoreServiceProvider);
    final paymentsSnap = await service.getPaymentsByBill(_bill.id).first;

    DocumentSnapshot<Map<String, dynamic>>? tenantSnap;
    DocumentSnapshot<Map<String, dynamic>>? flatSnap;
    try {
      tenantSnap = await service.getTenantDoc(_bill.tenantId);
      flatSnap = await service.getFlatDoc(_bill.flatId);
    } catch (_) {}

    final p = paymentsSnap.docs
        .map((d) => Payment.fromMap(d.id, d.data()))
        .toList();

    var previousReading = _bill.prevMeterReading;
    if (previousReading <= 0) {
      try {
        final previousMonth = BillGenerator.previousMonth(_bill.month);
        final prevBillsSnap = await service.getMonthBillsSnapshot(
          previousMonth,
        );
        final prevBill = prevBillsSnap.docs
            .map((d) => Bill.fromMap(d.id, d.data()))
            .where((b) => b.flatId == _bill.flatId)
            .firstOrNull;
        previousReading = prevBill?.currentMeterReading ?? 0;
      } catch (_) {}
    }

    Bill? latestBill;
    try {
      final billSnap = await service.getBill(_bill.id);
      if (billSnap.exists) {
        latestBill = Bill.fromMap(billSnap.id, billSnap.data()!);
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        if (latestBill != null) {
          _bill = latestBill!;
        }
        _tenant = tenantSnap?.exists == true
            ? Tenant.fromMap(tenantSnap!.id, tenantSnap.data()!)
            : null;
        _flat = flatSnap?.exists == true
            ? Flat.fromMap(flatSnap!.id, flatSnap.data()!)
            : null;
        _payments = p;
        _prevReading = previousReading;
        if (_previousReadingController.text.trim().isEmpty &&
            previousReading > 0) {
          _previousReadingController.text = previousReading.toStringAsFixed(0);
        }
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
    _previousReadingController.dispose();
    _currentReadingController.dispose();
    super.dispose();
  }

  double get _liveRent =>
      double.tryParse(_rentController.text.trim()) ?? _bill.rent;
  double get _liveGas =>
      double.tryParse(_gasController.text.trim()) ?? _bill.gas;
  double get _liveWater =>
      double.tryParse(_waterController.text.trim()) ?? _bill.water;
  double get _liveGarage =>
      double.tryParse(_garageController.text.trim()) ?? _bill.garage;

  double get _livePreviousReading {
    return double.tryParse(_previousReadingController.text.trim()) ??
        _prevReading;
  }

  double get _liveCurrentReading {
    return double.tryParse(_currentReadingController.text.trim()) ??
        _bill.currentMeterReading;
  }

  double get _liveElectricity {
    final current = _liveCurrentReading;
    final previous = _livePreviousReading;
    if (current > previous && _flat != null && _flat!.unitRate > 0) {
      return (current - previous) * _flat!.unitRate;
    }
    return double.parse(_electricityController.text.trim());
  }

  double get _liveTotal =>
      _liveRent + _liveGas + _liveWater + _liveGarage + _liveElectricity;

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
      final previousReading =
          double.tryParse(_previousReadingController.text.trim()) ??
          _prevReading;
      final currentReading =
          double.tryParse(_currentReadingController.text.trim()) ?? 0;
      double electricity;
      if (currentReading > previousReading &&
          _flat != null &&
          _flat!.unitRate > 0) {
        electricity = (currentReading - previousReading) * _flat!.unitRate;
      } else {
        electricity = double.parse(_electricityController.text.trim());
      }

      final updated = Bill(
        id: _bill.id,
        tenantId: _bill.tenantId,
        flatId: _bill.flatId,
        month: _bill.month,
        rent: _liveRent,
        gas: _liveGas,
        water: _liveWater,
        garage: _liveGarage,
        electricity: electricity,
        prevMeterReading: previousReading,
        currentMeterReading: currentReading,
        status: _bill.status,
        paidAmount: _bill.paidAmount,
        signedBy: _bill.signedBy,
      );

      await ref
          .read(firestoreServiceProvider)
          .updateBill(_bill.id, updated);

      if (mounted) {
        if (widget.updateOnly) {
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('বিল আপডেট করা হয়েছে'),
              backgroundColor: AppColors.success,
            ),
          );
        }
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
      if (mounted && !widget.updateOnly) setState(() => _isSaving = false);
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
      await ref.read(firestoreServiceProvider).deleteBill(_bill.id);
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

  Future<void> _deletePayment(Payment payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('নিশ্চিত করুন'),
        content: const Text('আপনি কি এই পেমেন্টটি মুছতে চান?'),
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

    try {
      final service = ref.read(firestoreServiceProvider);
      await service.deletePayment(payment.id);

      final newPaid = _bill.paidAmount - payment.amount;
      final newStatus = newPaid <= 0
          ? 'pending'
          : (newPaid >= _bill.total ? 'paid' : 'partial');
      final safePaid = newPaid < 0 ? 0 : newPaid;
      await service.updateBillPartial(_bill.id, {
        'paidAmount': safePaid,
        'status': newStatus,
        if (newStatus != 'paid') 'signedBy': '',
      });

      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('পেমেন্ট মুছে ফেলা হয়েছে'),
            backgroundColor: AppColors.success,
          ),
        );
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
    }
  }

  Future<void> _shareReceipt() async {
    final bill = _bill;
    if (bill.isPending) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('শুধুমাত্র পরিশোধিত বিলের রসিদ শেয়ার করা যাবে'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    try {
      final auth = ref.read(authServiceProvider);
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
        date: DateTime.now().toString().substring(0, 10),
        signatureName: bill.signedBy.isNotEmpty
            ? bill.signedBy
            : auth.currentDisplayName(),
        prevReadingLabel: _livePreviousReading > 0
            ? _livePreviousReading.toStringAsFixed(0)
            : '',
        currentReadingLabel: _liveCurrentReading > 0
            ? _liveCurrentReading.toStringAsFixed(0)
            : '',
      );

      await ExportService.shareFile(pdf, 'receipt_${bill.id}.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('রসিদ শেয়ার করা যায়নি: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bill = _bill;
    final auth = ref.read(authServiceProvider);
    final signatureName = bill.signedBy.isNotEmpty
        ? bill.signedBy
        : auth.currentDisplayName();
    final showSignature = bill.isPaid;
    final showUpdateOnly = widget.updateOnly;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          showUpdateOnly
              ? '${AppStrings.edit} ${BillGenerator.formatMonth(bill.month)}'
              : '${AppStrings.billDetails}: ${BillGenerator.formatMonth(bill.month)}',
        ),
        actions: [
          if (!showUpdateOnly && showSignature)
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
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Text(
                          _flatLabel,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          BillGenerator.formatMonth(bill.month),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (_tenant != null) ...[
                        const SizedBox(height: 4),
                        Center(
                          child: Text(
                            _tenant!.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: StatusBadge(status: bill.status),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _AmountField(
                        label: AppStrings.rent,
                        controller: _rentController,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      _AmountField(
                        label: AppStrings.gas,
                        controller: _gasController,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      _AmountField(
                        label: AppStrings.water,
                        controller: _waterController,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      _AmountField(
                        label: AppStrings.garage,
                        controller: _garageController,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      _AmountField(
                        label: AppStrings.electricity,
                        controller: _electricityController,
                        onChanged: (_) => setState(() {}),
                      ),
                      if (_flat != null && _flat!.unitRate > 0) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(left: 12),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withValues(
                              alpha: 0.06,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border(
                              left: BorderSide(
                                color: AppColors.primary.withValues(
                                  alpha: 0.35,
                                ),
                                width: 3,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.electricityReading,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _AmountField(
                                label: AppStrings.prevReading,
                                controller: _previousReadingController,
                                prefixText: '',
                                onChanged: (_) => setState(() {}),
                              ),
                              const SizedBox(height: 8),
                              _AmountField(
                                label: AppStrings.currentReading,
                                controller: _currentReadingController,
                                prefixText: '',
                                onChanged: (_) => setState(() {}),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${AppStrings.electricity}: ৳${_liveElectricity.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${AppStrings.total}: ৳${_liveTotal.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '${AppStrings.due}: ৳${(_liveTotal - bill.paidAmount).toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.pendingColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _save,
                          child: _isSaving
                              ? const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                )
                              : const Text(AppStrings.save),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!showUpdateOnly) ...[
                const SizedBox(height: 12),
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
                        _BillRow(
                          label: AppStrings.electricity,
                          amount: _liveElectricity,
                        ),
                        const Divider(height: 10),
                        _BillRow(
                          label: AppStrings.total,
                          amount: _liveTotal,
                          isBold: true,
                          color: AppColors.textPrimary,
                        ),
                        const Divider(height: 10),
                        _BillRow(
                          label: AppStrings.paidAmount,
                          amount: bill.paidAmount,
                          color: AppColors.paidColor,
                        ),
                        const Divider(height: 10),
                        _BillRow(
                          label: AppStrings.due,
                          amount: _liveTotal - bill.paidAmount,
                          isBold: true,
                          color: AppColors.pendingColor,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'পেমেন্ট',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text(AppStrings.collectPayment),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CollectPaymentScreen(bill: bill),
                          ),
                        );
                        _loadData();
                      },
                    ),
                  ],
                ),
                if (_payments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'কোনো পেমেন্ট নেই',
                      style: TextStyle(color: AppColors.textHint),
                    ),
                  )
                else
                  ...(_payments.map(
                    (p) => Card(
                      child: ListTile(
                        dense: true,
                        title: Text('৳${p.amount.toStringAsFixed(0)}'),
                        subtitle: Text(
                          '${p.method}  |  ${p.date.day}/${p.date.month}/${p.date.year}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: AppColors.error,
                            size: 20,
                          ),
                          onPressed: () => _deletePayment(p),
                        ),
                      ),
                    ),
                  )),
                const SizedBox(height: 16),
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
                        Row(
                          children: [
                            const Spacer(),
                            Text(
                              'ইলেকট্রনিক স্বাক্ষর',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Spacer(),
                            Icon(
                              Icons.edit_note,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              signatureName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 32),
              ],
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
  final String prefixText;
  final ValueChanged<String>? onChanged;
  const _AmountField({
    required this.label,
    required this.controller,
    this.prefixText = '৳ ',
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefixText,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
      keyboardType: TextInputType.number,
      onChanged: onChanged,
      validator: (v) => v?.isEmpty ?? true ? 'মান দিন' : null,
    );
  }
}

class _BillRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isBold;
  final Color? color;
  const _BillRow({
    required this.label,
    required this.amount,
    this.isBold = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isBold ? const TextStyle(fontWeight: FontWeight.bold) : null,
        ),
        Text(
          '৳${amount.toStringAsFixed(0)}',
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}
