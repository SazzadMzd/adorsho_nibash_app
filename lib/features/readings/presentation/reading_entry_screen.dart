import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/electricity_reading.dart';
import '../../../shared/providers.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../services/bill_generator.dart';

class ReadingEntryScreen extends ConsumerStatefulWidget {
  final String flatId;
  const ReadingEntryScreen({super.key, required this.flatId});

  @override
  ConsumerState<ReadingEntryScreen> createState() => _ReadingEntryScreenState();
}

class _ReadingEntryScreenState extends ConsumerState<ReadingEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentReadingController = TextEditingController();
  String _month = BillGenerator.currentMonth();
  double _previousReading = 0;
  double _unitRate = 0;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentReadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.electricityReading)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${AppStrings.prevReading}: ${_previousReading.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              Text('${AppStrings.month}: ${BillGenerator.formatMonth(_month)}'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _currentReadingController,
                decoration: const InputDecoration(
                  labelText: AppStrings.currentReading,
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v?.isEmpty ?? true ? 'রিডিং দিন' : null,
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
                      : const Text(AppStrings.save),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final reading = ElectricityReading(
        id: '',
        flatId: widget.flatId,
        month: _month,
        previousReading: _previousReading,
        currentReading: double.parse(_currentReadingController.text.trim()),
        unitRate: _unitRate,
      );

      await ref
          .read(firestoreServiceProvider)
          .addReading(reading);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('রিডিং সংরক্ষিত'),
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
