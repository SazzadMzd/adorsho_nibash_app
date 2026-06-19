import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/app_user_profile.dart';
import '../../../services/auth_service.dart';
import '../../../shared/providers.dart';
import '../../../shared/widgets/animations.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  Future<void> _openEditor({AppUserProfile? user}) async {
    final result = await showDialog<AppUserProfile>(
      context: context,
      builder: (_) => _UserEditorDialog(user: user),
    );
    if (result == null) return;

    final service = ref.read(firestoreServiceProvider);
    final auth = ref.read(authServiceProvider);

    if (user == null) {
      await service.addUser(result);
    } else {
      await service.updateUser(user.id, result);
    }

    if (auth.currentUser?.uid == user?.id) {
      await auth.updateUserName(result.name);
    }
  }

  Future<void> _deleteUser(AppUserProfile user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('নিশ্চিত করুন'),
        content: Text('${user.name} মুছে ফেলতে চান?'),
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

    await ref.read(firestoreServiceProvider).deleteUser(user.id);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authServiceProvider);
    if (!auth.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.userManagement)),
        body: const Center(
          child: Text('এই পেজটি শুধু অ্যাডমিনের জন্য'),
        ),
      );
    }

    final usersStream = ref.read(firestoreServiceProvider).getUsers();

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.userManagement),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.person_add),
        label: const Text(AppStrings.add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: usersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];
          final users = docs
              .map((d) => AppUserProfile.fromMap(d.id, d.data()))
              .toList()
            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

          if (users.isEmpty) {
            return const Center(child: Text('কোনো ব্যবহারকারী নেই'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final user = users[index];
              return AnimatedListItem(
                index: index,
                child: Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: user.isActive
                          ? AppColors.paidColor.withValues(alpha: 0.2)
                          : AppColors.pendingColor.withValues(alpha: 0.2),
                      child: Icon(
                        user.isActive ? Icons.person : Icons.person_off,
                        color: user.isActive ? AppColors.paidColor : AppColors.pendingColor,
                      ),
                    ),
                    title: Text(user.name.isNotEmpty ? user.name : 'নাম নেই'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.email.isNotEmpty ? user.email : 'ইমেইল নেই'),
                        const SizedBox(height: 2),
                        Text(user.isActive ? 'সক্রিয়' : 'নিষ্ক্রিয়'),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _openEditor(user: user);
                        } else if (value == 'delete') {
                          _deleteUser(user);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('সম্পাদনা')),
                        PopupMenuItem(value: 'delete', child: Text('মুছুন')),
                      ],
                    ),
                    onTap: () => _openEditor(user: user),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _UserEditorDialog extends StatefulWidget {
  final AppUserProfile? user;
  const _UserEditorDialog({this.user});

  @override
  State<_UserEditorDialog> createState() => _UserEditorDialogState();
}

class _UserEditorDialogState extends State<_UserEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _notesController;
  late bool _isActive;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user?.name ?? '');
    _emailController = TextEditingController(text: widget.user?.email ?? '');
    _notesController = TextEditingController(text: widget.user?.notes ?? '');
    _isActive = widget.user?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final now = DateTime.now();
    final existing = widget.user;
    Navigator.pop(
      context,
      AppUserProfile(
        id: existing?.id ?? '',
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        isActive: _isActive,
        notes: _notesController.text.trim(),
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.user == null ? 'নতুন ব্যবহারকারী' : 'ব্যবহারকারী সম্পাদনা'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'নাম'),
                  validator: (v) => (v?.trim().isEmpty ?? true) ? 'নাম দিন' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'ইমেইল'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v?.trim().isEmpty ?? true) ? 'ইমেইল দিন' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: 'নোট'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('সক্রিয়'),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(AppStrings.cancel),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text(AppStrings.save),
        ),
      ],
    );
  }
}
