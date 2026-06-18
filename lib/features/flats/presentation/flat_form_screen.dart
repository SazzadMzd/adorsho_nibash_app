import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/flat.dart';
import '../../../shared/providers.dart';

class FlatFormScreen extends ConsumerStatefulWidget {
  final Flat? flat;
  const FlatFormScreen({super.key, this.flat});

  @override
  ConsumerState<FlatFormScreen> createState() => _FlatFormScreenState();
}

class _FlatFormScreenState extends ConsumerState<FlatFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _flatNoController;
  late final TextEditingController _floorController;
  late final TextEditingController _rentController;
  late final TextEditingController _gasController;
  late final TextEditingController _waterController;
  late final TextEditingController _garageController;
  late final TextEditingController _meterController;
  late final TextEditingController _unitRateController;
  bool _isLoading = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _flatNoController = TextEditingController(text: widget.flat?.flatNo ?? '');
    _floorController = TextEditingController(text: widget.flat?.floor ?? '');
    _rentController =
        TextEditingController(text: widget.flat?.rent.toString() ?? '');
    _gasController =
        TextEditingController(text: widget.flat?.gas.toString() ?? '0');
    _waterController =
        TextEditingController(text: widget.flat?.water.toString() ?? '0');
    _garageController =
        TextEditingController(text: widget.flat?.garage.toString() ?? '0');
    _meterController = TextEditingController(text: widget.flat?.meterNo ?? '');
    _unitRateController =
        TextEditingController(text: widget.flat?.unitRate.toString() ?? '0');
  }

  @override
  void dispose() {
    _flatNoController.dispose();
    _floorController.dispose();
    _rentController.dispose();
    _gasController.dispose();
    _waterController.dispose();
    _garageController.dispose();
    _meterController.dispose();
    _unitRateController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final flat = Flat(
        id: widget.flat?.id ?? '',
        flatNo: _flatNoController.text.trim(),
        floor: _floorController.text.trim(),
        rent: double.parse(_rentController.text.trim()),
        gas: double.tryParse(_gasController.text.trim()) ?? 0,
        water: double.tryParse(_waterController.text.trim()) ?? 0,
        garage: double.tryParse(_garageController.text.trim()) ?? 0,
        meterNo: _meterController.text.trim(),
        unitRate: double.tryParse(_unitRateController.text.trim()) ?? 0,
      );

      final service = ref.read(firestoreServiceProvider);
      if (widget.flat != null) {
        await service.updateFlat(widget.flat!.id, flat);
      } else {
        await service.addFlat(flat);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.flat != null ? 'আপডেট করা হয়েছে' : 'যোগ করা হয়েছে'),
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

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.flat != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? AppStrings.editFlat : AppStrings.addFlat),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _flatNoController,
                decoration: const InputDecoration(labelText: AppStrings.flatNo),
                validator: (v) => v?.isEmpty ?? true ? 'ফ্ল্যাট নম্বর দিন' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _floorController,
                decoration: const InputDecoration(labelText: AppStrings.floor),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _rentController,
                decoration: const InputDecoration(
                  labelText: AppStrings.monthlyRent,
                  prefixText: '৳ ',
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v?.isEmpty ?? true ? 'ভাড়া দিন' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _gasController,
                      decoration: const InputDecoration(
                        labelText: AppStrings.gasBill,
                        prefixText: '৳ ',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _waterController,
                      decoration: const InputDecoration(
                        labelText: AppStrings.waterBill,
                        prefixText: '৳ ',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _garageController,
                      decoration: const InputDecoration(
                        labelText: AppStrings.garageBill,
                        prefixText: '৳ ',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _meterController,
                      decoration: const InputDecoration(
                        labelText: AppStrings.meterNo,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _unitRateController,
                decoration: const InputDecoration(
                  labelText: AppStrings.unitRate,
                  prefixText: '৳ ',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
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
                      : Text(isEdit ? AppStrings.save : AppStrings.addFlat),
                ),
              ),
              if (isEdit) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _isDeleting ? null : _confirmDelete,
                    icon: _isDeleting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.delete, color: AppColors.error),
                    label: Text(AppStrings.delete,
                        style: const TextStyle(color: AppColors.error)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('নিশ্চিত করুন'),
        content: const Text('আপনি কি এই ফ্ল্যাটটি মুছতে চান?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(AppStrings.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(AppStrings.delete)),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      await ref.read(firestoreServiceProvider).deleteFlat(widget.flat!.id);
      if (mounted) Navigator.pop(context);
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
}
