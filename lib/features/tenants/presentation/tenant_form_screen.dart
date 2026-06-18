import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/tenant.dart';
import '../../../shared/providers.dart';

class TenantFormScreen extends ConsumerStatefulWidget {
  final Tenant? tenant;
  const TenantFormScreen({super.key, this.tenant});

  @override
  ConsumerState<TenantFormScreen> createState() => _TenantFormScreenState();
}

class _TenantFormScreenState extends ConsumerState<TenantFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _nidController;
  late final TextEditingController _depositController;
  String? _selectedFlatId;
  DateTime _joinDate = DateTime.now();
  bool _isLoading = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.tenant?.name ?? '');
    _phoneController = TextEditingController(text: widget.tenant?.phone ?? '');
    _nidController = TextEditingController(text: widget.tenant?.nid ?? '');
    _depositController =
        TextEditingController(text: widget.tenant?.securityDeposit.toString() ?? '0');
    _selectedFlatId = widget.tenant?.flatId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _nidController.dispose();
    _depositController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFlatId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ফ্ল্যাট নির্বাচন করুন')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final tenant = Tenant(
        id: widget.tenant?.id ?? '',
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        nid: _nidController.text.trim(),
        flatId: _selectedFlatId!,
        joinedAt: _joinDate,
        securityDeposit: double.tryParse(_depositController.text.trim()) ?? 0,
      );

      final service = ref.read(firestoreServiceProvider);
      if (widget.tenant != null) {
        await service.updateTenant(widget.tenant!.id, tenant);
      } else {
        await service.addTenant(tenant);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ভাড়াটিয়া যোগ করা হয়েছে')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ত্রুটি: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flatsAsync = ref.watch(flatListProvider);

    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.tenant != null ? AppStrings.editTenant : AppStrings.addTenant),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: AppStrings.tenantName),
                validator: (v) => v?.isEmpty ?? true ? 'নাম দিন' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: AppStrings.phone,
                  prefixText: '+880 ',
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nidController,
                decoration: const InputDecoration(
                  labelText: AppStrings.nid,
                ),
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 12),
              flatsAsync.when(
                data: (flats) => DropdownButtonFormField<String>(
                  initialValue: _selectedFlatId,
                  decoration:
                      const InputDecoration(labelText: AppStrings.selectFlat),
                  items: flats
                      .where((f) => f.isActive)
                      .map((f) => DropdownMenuItem(
                            value: f.id,
                            child: Text(f.floor.isNotEmpty
                                ? '${f.floor} - ${f.flatNo}'
                                : f.flatNo),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedFlatId = v),
                ),
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('$e'),
              ),
              const SizedBox(height: 12),
              ListTile(
                title: const Text(AppStrings.joinDate),
                subtitle: Text(
                  '${_joinDate.day}/${_joinDate.month}/${_joinDate.year}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _joinDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _joinDate = picked);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _depositController,
                decoration: const InputDecoration(
                  labelText: AppStrings.securityDeposit,
                  prefixText: '৳ ',
                ),
                keyboardType: TextInputType.number,
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
                      : Text(widget.tenant != null
                          ? AppStrings.save
                          : AppStrings.addTenant),
                ),
              ),
              if (widget.tenant != null) ...[
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
        content: const Text('আপনি কি এই ভাড়াটিয়া মুছতে চান?'),
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
      await ref.read(firestoreServiceProvider).deleteTenant(widget.tenant!.id);
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
