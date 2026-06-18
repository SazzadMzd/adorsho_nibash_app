import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/bill.dart';
import '../../../models/payment.dart';
import '../../../shared/providers.dart';
import '../../../services/bill_generator.dart';

class CollectPaymentScreen extends ConsumerStatefulWidget {
  final Bill? bill;
  const CollectPaymentScreen({super.key, this.bill});

  @override
  ConsumerState<CollectPaymentScreen> createState() =>
      _CollectPaymentScreenState();
}

class _CollectPaymentScreenState extends ConsumerState<CollectPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String _selectedMethod = 'cash';
  DateTime _paymentDate = DateTime.now();
  bool _isLoading = false;
  Bill? _selectedBill;

  @override
  void initState() {
    super.initState();
    _selectedBill = widget.bill;
    if (_selectedBill != null) {
      _amountController.text = _selectedBill!.due.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBill == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('বিল নির্বাচন করুন')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final amount = double.parse(_amountController.text.trim());
      final service = ref.read(firestoreServiceProvider);

      final payment = Payment(
        id: '',
        billId: _selectedBill!.id,
        tenantId: _selectedBill!.tenantId,
        amount: amount,
        method: _selectedMethod,
        date: _paymentDate,
        note: _noteController.text.trim(),
      );

      await service.addPayment(payment);

      final newPaid = _selectedBill!.paidAmount + amount;
      final newStatus = newPaid >= _selectedBill!.total ? 'paid' : 'partial';
      await service.updateBillPartial(_selectedBill!.id, {
        'paidAmount': newPaid,
        'status': newStatus,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('টাকা গ্রহণ করা হয়েছে'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('ত্রুটি: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.collectPayment)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_selectedBill != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'বিল: ${BillGenerator.formatMonth(_selectedBill!.month)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                            '${AppStrings.total}: ৳${_selectedBill!.total.toStringAsFixed(0)}'),
                        Text(
                          '${AppStrings.due}: ৳${_selectedBill!.due.toStringAsFixed(0)}',
                          style:
                              const TextStyle(color: AppColors.pendingColor),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: AppStrings.paymentAmount,
                  prefixText: '৳ ',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v?.isEmpty ?? true) return 'পরিমাণ দিন';
                  final amount = double.tryParse(v!);
                  if (amount == null || amount <= 0) return 'সঠিক পরিমাণ দিন';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedMethod,
                decoration:
                    const InputDecoration(labelText: AppStrings.paymentMethod),
                items: AppStrings.paymentMethods.entries
                    .map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedMethod = v!),
              ),
              const SizedBox(height: 12),
              ListTile(
                title: const Text(AppStrings.paymentDate),
                subtitle: Text(
                  '${_paymentDate.day}/${_paymentDate.month}/${_paymentDate.year}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _paymentDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _paymentDate = picked);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: AppStrings.paymentNote,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white)
                      : const Text(AppStrings.collectPayment),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
