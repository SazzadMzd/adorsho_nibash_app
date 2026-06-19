import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/electricity_reading.dart';
import '../../../models/flat.dart';
import '../../../models/bill.dart';
import '../../../shared/providers.dart';
import '../../../shared/widgets/animations.dart';
import '../../../services/bill_generator.dart';

class ReadingEntryScreen extends ConsumerStatefulWidget {
  final String flatId;
  final String? flatNo;
  const ReadingEntryScreen({super.key, required this.flatId, this.flatNo});

  @override
  ConsumerState<ReadingEntryScreen> createState() => _ReadingEntryScreenState();
}

class _ReadingEntryScreenState extends ConsumerState<ReadingEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentReadingController = TextEditingController();
  final String _month = BillGenerator.currentMonth();
  double _previousReading = 0;
  double _unitRate = 0;
  bool _isLoading = false;
  bool _dataLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final service = ref.read(firestoreServiceProvider);
    final lastReading = await service.getLastReading(widget.flatId);
    final flatsSnap = await service.getFlats().first;
    final flat = flatsSnap.docs
        .map((d) => Flat.fromMap(d.id, d.data()))
        .where((f) => f.id == widget.flatId)
        .firstOrNull;

    if (mounted) {
      setState(() {
        _previousReading = lastReading?.data()?['currentReading'] ?? 0;
        _unitRate = flat?.unitRate ?? 0;
        _dataLoaded = true;
      });
    }
  }

  @override
  void dispose() {
    _currentReadingController.dispose();
    super.dispose();
  }

  double get _unitsUsed {
    final current = double.tryParse(_currentReadingController.text.trim()) ?? 0;
    return current - _previousReading;
  }

  double get _electricityCost => _unitsUsed * _unitRate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.flatNo != null
            ? '${AppStrings.electricityReading} - ${widget.flatNo}'
            : AppStrings.electricityReading),
      ),
      body: AnimatedPageEntrance(
        slideOffset: 16,
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_dataLoaded)
                const Center(child: CircularProgressIndicator())
              else ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${AppStrings.month}: ${BillGenerator.formatMonth(_month)}'),
                        Text('${AppStrings.prevReading}: ${_previousReading.toStringAsFixed(0)}'),
                        Text('${AppStrings.unitRate}: ৳${_unitRate.toStringAsFixed(2)}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _currentReadingController,
                  decoration: const InputDecoration(
                    labelText: AppStrings.currentReading,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    if (v?.isEmpty ?? true) return 'রিডিং দিন';
                    final val = double.tryParse(v!);
                    if (val == null || val < _previousReading) {
                      return 'বর্তমান রিডিং আগের রিডিং ($_previousReading) থেকে বড় হতে হবে';
                    }
                    return null;
                  },
                ),
                if (_currentReadingController.text.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: AppColors.primaryLight.withValues(alpha: 0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Text('${AppStrings.unitsUsed}: ${_unitsUsed.toStringAsFixed(0)}'),
                          Text('${AppStrings.electricity}: ৳${_electricityCost.toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    child: _isLoading
                        ? const CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white)
                        : const Text(AppStrings.save),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final service = ref.read(firestoreServiceProvider);

      final reading = ElectricityReading(
        id: '',
        flatId: widget.flatId,
        month: _month,
        previousReading: _previousReading,
        currentReading: double.parse(_currentReadingController.text.trim()),
        unitRate: _unitRate,
      );

      await service.addReading(reading);

      // Update bill for this flat+month with calculated electricity
      final existingBills = await service.getMonthBillsSnapshot(_month);
      final billDoc = existingBills.docs
          .map((d) => (id: d.id, bill: Bill.fromMap(d.id, d.data())))
          .where((b) => b.bill.flatId == widget.flatId)
          .firstOrNull;

      if (billDoc != null) {
        await service.updateBill(billDoc.id, billDoc.bill.copyWith(
          electricity: _electricityCost,
          prevMeterReading: _previousReading,
          currentMeterReading: double.parse(_currentReadingController.text.trim()),
        ));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('রিডিং সংরক্ষিত এবং বিল আপডেট করা হয়েছে'),
            backgroundColor: AppColors.success,
          ),
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
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
