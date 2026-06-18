import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/bill.dart';
import '../../../models/payment.dart';
import '../../../models/flat.dart';
import '../../../models/tenant.dart';
import '../../../services/bill_generator.dart';
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
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isDeleting = false;
  List<Payment> _payments = [];
  Tenant? _tenant;
  Flat? _flat;

  @override
  void initState() {
    super.initState();
    _rentController = TextEditingController(text: widget.bill.rent.toStringAsFixed(0));
    _gasController = TextEditingController(text: widget.bill.gas.toStringAsFixed(0));
    _waterController = TextEditingController(text: widget.bill.water.toStringAsFixed(0));
    _garageController = TextEditingController(text: widget.bill.garage.toStringAsFixed(0));
    _electricityController = TextEditingController(text: widget.bill.electricity.toStringAsFixed(0));
    _loadData();
  }

  Future<void> _loadData() async {
    final service = ref.read(firestoreServiceProvider);
    final tenants = await service.getAllTenants().first;
    final flats = await service.getFlats().first;
    final paymentsSnap = await service.getPaymentsByBill(widget.bill.id).first;

    final t = tenants.docs
        .map((d) => Tenant.fromMap(d.id, d.data()))
        .where((t) => t.id == widget.bill.tenantId)
        .firstOrNull;
    final f = flats.docs
        .map((d) => Flat.fromMap(d.id, d.data()))
        .where((f) => f.id == widget.bill.flatId)
        .firstOrNull;
    final p = paymentsSnap.docs
        .map((d) => Payment.fromMap(d.id, d.data()))
        .toList();

    if (mounted) {
      setState(() {
        _tenant = t;
        _flat = f;
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
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final updated = Bill(
        id: widget.bill.id,
        tenantId: widget.bill.tenantId,
        flatId: widget.bill.flatId,
        month: widget.bill.month,
        rent: double.parse(_rentController.text.trim()),
        gas: double.parse(_gasController.text.trim()),
        water: double.parse(_waterController.text.trim()),
        garage: double.parse(_garageController.text.trim()),
        electricity: double.parse(_electricityController.text.trim()),
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

  @override
  Widget build(BuildContext context) {
    final bill = widget.bill;
    final authUser = ref.read(authServiceProvider).currentUser;
    final signatureName = authUser?.displayName ?? authUser?.email ?? 'Unknown';

    return Scaffold(
      appBar: AppBar(
        title: Text('${AppStrings.billDetails}: ${BillGenerator.formatMonth(bill.month)}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: AppColors.error),
            onPressed: _isDeleting ? null : _deleteBill,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Header: App name + flat floor-room
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(AppStrings.appName,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold, color: AppColors.primary)),
                      const SizedBox(height: 12),
                      if (_flat != null)
                        Text('${AppStrings.floor}: ${_flat!.floor}  |  ${AppStrings.flatNo}: ${_flat!.flatNo}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(BillGenerator.formatMonth(bill.month),
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Tenant info
              if (_tenant != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const CircleAvatar(child: Icon(Icons.person)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_tenant!.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              if (_tenant!.phone.isNotEmpty) Text('${AppStrings.phone}: ${_tenant!.phone}'),
                              if (_tenant!.nid.isNotEmpty) Text('${AppStrings.nid}: ${_tenant!.nid}'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // Bill breakdown table
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _BillRow(label: AppStrings.rent, amount: bill.rent),
                      const Divider(height: 12),
                      _BillRow(label: AppStrings.gas, amount: bill.gas),
                      const Divider(height: 12),
                      _BillRow(label: AppStrings.water, amount: bill.water),
                      const Divider(height: 12),
                      _BillRow(label: AppStrings.garage, amount: bill.garage),
                      const Divider(height: 12),
                      _BillRow(label: AppStrings.electricity, amount: bill.electricity),
                      const Divider(height: 12),
                      _BillRow(label: AppStrings.total, amount: bill.total,
                          isBold: true, color: AppColors.textPrimary),
                      const Divider(height: 12),
                      _BillRow(label: AppStrings.paidAmount, amount: bill.paidAmount,
                          color: AppColors.paidColor),
                      const Divider(height: 12),
                      _BillRow(label: AppStrings.due, amount: bill.due,
                          isBold: true, color: AppColors.pendingColor),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerRight, child: StatusBadge(status: bill.status)),
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
              const SizedBox(height: 24),

              // Electronic signature
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
