import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/tenant.dart';
import '../../../shared/providers.dart';
import '../../../shared/widgets/animations.dart';

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
  late final TextEditingController _depositController;
  final ImagePicker _picker = ImagePicker();
  File? _nidImageFile;
  String? _nidImageUrl;
  String? _selectedFlatId;
  DateTime _joinDate = DateTime.now();
  bool _isLoading = false;
  bool _isDeleting = false;
  bool _isMarkingLeft = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.tenant?.name ?? '');
    _phoneController = TextEditingController(text: widget.tenant?.phone ?? '');
    _depositController =
        TextEditingController(text: widget.tenant?.securityDeposit.toString() ?? '0');
    _nidImageUrl = widget.tenant?.nidImageUrl;
    _selectedFlatId = widget.tenant?.flatId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _depositController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, maxWidth: 1024, maxHeight: 1024);
    if (picked != null) {
      setState(() => _nidImageFile = File(picked.path));
    }
  }

  void _showImageOptions() {
    final hasImage = _nidImageFile != null || (_nidImageUrl != null && _nidImageUrl!.isNotEmpty);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            if (hasImage)
              ListTile(
                leading: const Icon(Icons.visibility),
                title: const Text('দেখুন'),
                onTap: () {
                  Navigator.pop(ctx);
                  _viewImageFullScreen();
                },
              ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('ক্যামেরা'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('গ্যালারি'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (hasImage)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: const Text('ছবি সরান', style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _nidImageFile = null;
                    _nidImageUrl = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  void _viewImageFullScreen() {
    Widget imageWidget;
    if (_nidImageFile != null) {
      imageWidget = Image.file(_nidImageFile!, fit: BoxFit.contain);
    } else if (_nidImageUrl != null && _nidImageUrl!.isNotEmpty) {
      if (_nidImageUrl!.startsWith('data:image')) {
        imageWidget = Image.memory(
          base64Decode(_nidImageUrl!.split(',').last),
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 64),
        );
      } else {
        imageWidget = Image.network(_nidImageUrl!, fit: BoxFit.contain);
      }
    } else {
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(child: imageWidget),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _encodeImageToBase64(File file) async {
    final bytes = await file.readAsBytes();
    final base64Str = base64Encode(bytes);
    return 'data:image/jpeg;base64,$base64Str';
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
      final activeTenants = await ref.read(activeTenantListProvider.future);
      final existingTenant = activeTenants.cast<Tenant?>().firstWhere(
        (t) => t!.flatId == _selectedFlatId && t.id != widget.tenant?.id,
        orElse: () => null,
      );
      if (existingTenant != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('এই ফ্ল্যাটে ইতিমধ্যে একজন সক্রিয় ভাড়াটিয়া আছে'),
              backgroundColor: AppColors.error,
            ),
          );
          setState(() => _isLoading = false);
        }
        return;
      }

      final service = ref.read(firestoreServiceProvider);
      final isNew = widget.tenant == null;

      if (isNew) {
        final imageUrl = _nidImageFile != null
            ? await _encodeImageToBase64(_nidImageFile!)
            : null;

        final tenant = Tenant(
          id: '',
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          nidImageUrl: imageUrl ?? '',
          flatId: _selectedFlatId!,
          joinedAt: _joinDate,
          securityDeposit: double.tryParse(_depositController.text.trim()) ?? 0,
        );
        await service.addTenant(tenant);
      } else {
        final imageUrl = _nidImageFile != null
            ? await _encodeImageToBase64(_nidImageFile!)
            : _nidImageUrl ?? '';

        final tenant = Tenant(
          id: widget.tenant!.id,
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          nidImageUrl: imageUrl,
          flatId: _selectedFlatId!,
          joinedAt: _joinDate,
          securityDeposit: double.tryParse(_depositController.text.trim()) ?? 0,
        );
        await service.updateTenant(widget.tenant!.id, tenant);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isNew ? 'ভাড়াটিয়া যোগ করা হয়েছে' : 'আপডেট করা হয়েছে'),
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
    final flatsAsync = ref.watch(flatListProvider);

    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.tenant != null ? AppStrings.editTenant : AppStrings.addTenant),
      ),
      body: AnimatedPageEntrance(
        slideOffset: 16,
        child: SingleChildScrollView(
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
              GestureDetector(
                onTap: _showImageOptions,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: _nidImageFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.file(_nidImageFile!, height: 180, fit: BoxFit.cover),
                        )
                      : _nidImageUrl != null && _nidImageUrl!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: _nidImageUrl!.startsWith('data:image')
                                  ? Image.memory(
                                      base64Decode(_nidImageUrl!.split(',').last),
                                      height: 180,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 48),
                                    )
                                  : Image.network(_nidImageUrl!, height: 180, fit: BoxFit.cover),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt, color: Colors.grey.shade600),
                                const SizedBox(width: 8),
                                Text(
                                  'এনআইডি ছবি তুলুন',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                                ),
                              ],
                            ),
                ),
              ),
              const SizedBox(height: 12),
              flatsAsync.when(
                data: (flats) => DropdownButtonFormField<String>(
                  initialValue: _selectedFlatId,
                  decoration:
                      const InputDecoration(labelText: AppStrings.selectFlat),
                  items: flats
                      .where((f) => f.isActive || f.id == _selectedFlatId)
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
                if (widget.tenant!.isActive)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _isMarkingLeft ? null : _markAsLeft,
                      icon: _isMarkingLeft
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.exit_to_app, color: AppColors.warning),
                      label: Text(AppStrings.markLeft,
                          style: const TextStyle(color: AppColors.warning)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.warning),
                      ),
                    ),
                  ),
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

  Future<void> _markAsLeft() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('নিশ্চিত করুন'),
        content: const Text('আপনি কি এই ভাড়াটিয়াকে "চলে গেছেন" হিসেবে চিহ্নিত করতে চান?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(AppStrings.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(AppStrings.confirm)),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isMarkingLeft = true);
    try {
      final tenant = widget.tenant!.copyWith(
        status: 'left',
        leftAt: DateTime.now(),
      );
      await ref.read(firestoreServiceProvider).updateTenant(widget.tenant!.id, tenant);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ভাড়াটিয়াকে চলে গেছেন হিসেবে চিহ্নিত করা হয়েছে'),
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
      if (mounted) setState(() => _isMarkingLeft = false);
    }
  }
}
