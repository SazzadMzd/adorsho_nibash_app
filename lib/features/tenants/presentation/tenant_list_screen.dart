import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/flat.dart';
import '../../../models/tenant.dart';
import '../../../shared/providers.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/animations.dart';
import 'tenant_form_screen.dart';

class TenantListScreen extends ConsumerWidget {
  const TenantListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantsAsync = ref.watch(tenantListProvider);
    final flatsAsync = ref.watch(flatListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.tenants)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TenantFormScreen()),
        ),
        child: const Icon(Icons.person_add),
      ),
      body: flatsAsync.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => Center(child: Text('$e')),
        data: (flats) {
          final flatMap = {for (final f in flats) f.id: f};
          return tenantsAsync.when(
            loading: () => const LoadingWidget(),
            error: (e, _) => Center(child: Text('$e')),
            data: (tenants) {
              if (tenants.isEmpty) {
                return EmptyState(
                  icon: Icons.people_outline,
                  message: AppStrings.noTenants,
                  actionLabel: AppStrings.addTenant,
                  onAction: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TenantFormScreen()),
                  ),
                );
              }
              return ListView.builder(
                itemCount: tenants.length,
                itemBuilder: (_, i) => AnimatedListItem(
                  index: i,
                  child: _TenantCard(
                    tenant: tenants[i],
                    flatLabel: _flatLabel(flatMap[tenants[i].flatId]),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TenantFormScreen(tenant: tenants[i]),
                      ),
                    ),
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

String _flatLabel(Flat? flat) {
  if (flat == null) return '';
  if (flat.floor.isNotEmpty) return '${flat.floor} - ${flat.flatNo}';
  return flat.flatNo;
}

class _TenantCard extends StatelessWidget {
  final Tenant tenant;
  final String flatLabel;
  final VoidCallback onTap;
  const _TenantCard({required this.tenant, required this.flatLabel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: tenant.isActive
              ? AppColors.paidColor.withValues(alpha: 0.2)
              : AppColors.pendingColor.withValues(alpha: 0.2),
          child: Icon(
            Icons.person,
            color: tenant.isActive ? AppColors.paidColor : AppColors.pendingColor,
          ),
        ),
        title: Text(tenant.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          flatLabel.isNotEmpty
              ? '$flatLabel  |  ${AppStrings.securityDeposit}: ৳${tenant.securityDeposit.toStringAsFixed(0)}'
              : '${AppStrings.securityDeposit}: ৳${tenant.securityDeposit.toStringAsFixed(0)}',
        ),
        trailing: tenant.isActive
            ? const Icon(Icons.check_circle, color: AppColors.paidColor, size: 20)
            : const Icon(Icons.cancel, color: AppColors.pendingColor, size: 20),
        onTap: onTap,
      ),
    );
  }
}
