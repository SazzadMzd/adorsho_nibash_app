import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/bill.dart';
import '../../../models/electricity_reading.dart';
import '../../../services/bill_generator.dart';
import '../../../shared/providers.dart';

class BillGenerationScreen extends ConsumerStatefulWidget {
  const BillGenerationScreen({super.key});

  @override
  ConsumerState<BillGenerationScreen> createState() => _BillGenerationScreenState();
}

class _BillGenerationScreenState extends ConsumerState<BillGenerationScreen> {
  String _selectedMonth = BillGenerator.currentMonth();
  bool _isGenerating = false;

  Future<void> _generate() async {
    setState(() => _isGenerating = true);
    try {
      final service = ref.read(firestoreServiceProvider);
      final flatList = await ref.read(flatListProvider.future);
      final tenants = await ref.read(activeTenantListProvider.future);

      final existingSnap = await service.getMonthBillsSnapshot(_selectedMonth);
      final existingTenantIds = existingSnap.docs
          .map((d) => Bill.fromMap(d.id, d.data()).tenantId)
          .toSet();

      final flatMap = {for (final f in flatList) f.id: f};
      final missingTenants = tenants.where((t) => !existingTenantIds.contains(t.id)).toList();

      if (missingTenants.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('এই মাসের জন্য সকল ভাড়াটিয়ার বিল ইতিমধ্যে তৈরি হয়েছে'),
              backgroundColor: AppColors.info,
            ),
          );
        }
        return;
      }

      final readingsSnap = await service.getReadingsByMonth(_selectedMonth);
      final readingsByFlatId = {
        for (final d in readingsSnap.docs)
          ElectricityReading.fromMap(d.id, d.data()).flatId:
              ElectricityReading.fromMap(d.id, d.data()),
      };
      final previousMonth = BillGenerator.previousMonth(_selectedMonth);
      final previousBillsSnap = await service.getMonthBillsSnapshot(previousMonth);
      final previousBillsByFlatId = {
        for (final d in previousBillsSnap.docs)
          Bill.fromMap(d.id, d.data()).flatId: Bill.fromMap(d.id, d.data()),
      };

      final bills = BillGenerator.createBills(
        _selectedMonth,
        missingTenants,
        flatMap,
        readingsByFlatId,
        previousBillsByFlatId,
      );
      for (final bill in bills) {
        await service.addBill(bill);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${bills.length} টি বিল তৈরি হয়েছে'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ত্রুটি: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final billsAsync = ref.watch(billByMonthProvider(_selectedMonth));
    final tenantsAsync = ref.watch(activeTenantListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.generateBills)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _selectedMonth,
                    decoration: const InputDecoration(labelText: AppStrings.month),
                    items: _monthOptions(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedMonth = v);
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isGenerating ? null : _generate,
                      icon: _isGenerating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.auto_awesome),
                      label: Text(_isGenerating ? 'তৈরি হচ্ছে...' : AppStrings.generateBills),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('এই মাসের বিল', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          billsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('$e'),
            data: (bills) {
              if (bills.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('এই মাসের জন্য কোনো বিল নেই', style: TextStyle(color: AppColors.textHint)),
                  ),
                );
              }
              return Column(
                children: bills.map((b) => _ExistingBillTile(bill: b)).toList(),
              );
            },
          ),
          const SizedBox(height: 16),
          tenantsAsync.when(
            loading: () => const SizedBox(),
            data: (tenants) {
              final active = tenants.where((t) => t.isActive).toList();
              return Text('সক্রিয় ভাড়াটিয়া: ${active.length} জন');
            },
            error: (e, _) => Text('$e'),
          ),
        ],
      ),
    );
  }

  List<DropdownMenuItem<String>> _monthOptions() {
    final now = DateTime.now();
    final items = <DropdownMenuItem<String>>[];
    for (var i = -3; i <= 1; i++) {
      final d = DateTime(now.year, now.month + i, 1);
      final m = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      items.add(DropdownMenuItem(value: m, child: Text(BillGenerator.formatMonth(m))));
    }
    return items;
  }
}

class _ExistingBillTile extends StatelessWidget {
  final Bill bill;
  const _ExistingBillTile({required this.bill});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text('বিল #${bill.id.substring(0, 6)}'),
        subtitle: Text('${AppStrings.total}: ৳${bill.total.toStringAsFixed(0)}'),
        trailing: Icon(
          bill.isPaid ? Icons.check_circle : Icons.pending,
          color: bill.isPaid ? AppColors.paidColor : AppColors.pendingColor,
        ),
      ),
    );
  }
}
