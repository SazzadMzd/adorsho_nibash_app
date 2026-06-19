import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/flat.dart';
import '../../../shared/providers.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/animations.dart';
import 'flat_form_screen.dart';

class FlatListScreen extends ConsumerWidget {
  const FlatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flatsAsync = ref.watch(flatListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.flats)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FlatFormScreen()),
        ),
        child: const Icon(Icons.add),
      ),
      body: flatsAsync.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => Center(child: Text('$e')),
        data: (flats) {
          if (flats.isEmpty) {
            return EmptyState(
              icon: Icons.apartment,
              message: AppStrings.noFlats,
              actionLabel: AppStrings.addFlat,
              onAction: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FlatFormScreen()),
              ),
            );
          }
          return ListView.builder(
            itemCount: flats.length,
            itemBuilder: (_, i) => AnimatedListItem(
              index: i,
              child: _FlatCard(
                flat: flats[i],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FlatFormScreen(flat: flats[i]),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FlatCard extends StatelessWidget {
  final Flat flat;
  final VoidCallback onTap;

  const _FlatCard({required this.flat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: flat.isActive
              ? AppColors.primaryLight.withValues(alpha: 0.2)
              : AppColors.textHint.withValues(alpha: 0.2),
          child: Icon(
            Icons.apartment,
            color: flat.isActive ? AppColors.primary : AppColors.textHint,
          ),
        ),
        title: Text(
          flat.floor.isNotEmpty ? '${flat.floor} - ${flat.flatNo}' : flat.flatNo,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${AppStrings.monthlyRent}: ৳${flat.rent.toStringAsFixed(0)}'),
        trailing: flat.isActive
            ? const Icon(Icons.check_circle, color: AppColors.paidColor, size: 20)
            : const Icon(Icons.cancel, color: AppColors.pendingColor, size: 20),
        onTap: onTap,
      ),
    );
  }
}
