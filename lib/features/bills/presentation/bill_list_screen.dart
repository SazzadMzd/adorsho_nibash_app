import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/bill.dart';
import '../../../services/bill_generator.dart';
import '../../../shared/providers.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../payments/presentation/collect_payment_screen.dart';

class BillListScreen extends ConsumerStatefulWidget {
  final String? initialFilter;
  const BillListScreen({super.key, this.initialFilter});

  @override
  ConsumerState<BillListScreen> createState() => _BillListScreenState();
}

class _BillListScreenState extends ConsumerState<BillListScreen> {
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter ?? 'all';
  }

  @override
  Widget build(BuildContext context) {
    final billsAsync = ref.watch(billsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.bills),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (v) => setState(() => _selectedFilter = v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'all', child: Text(AppStrings.all)),
              const PopupMenuItem(
                  value: 'pending', child: Text(AppStrings.statusPending)),
              const PopupMenuItem(
                  value: 'partial', child: Text(AppStrings.statusPartial)),
              const PopupMenuItem(
                  value: 'paid', child: Text(AppStrings.statusPaid)),
            ],
          ),
        ],
      ),
      body: billsAsync.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => Center(child: Text('$e')),
        data: (bills) {
          var filtered = bills;
          if (_selectedFilter != 'all') {
            filtered = bills.where((b) => b.status == _selectedFilter).toList();
          }
          filtered.sort((a, b) => b.month.compareTo(a.month));

          if (filtered.isEmpty) {
            return EmptyState(icon: Icons.receipt_long, message: AppStrings.noBills);
          }
          return ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (_, i) => _BillCard(bill: filtered[i]),
          );
        },
      ),
    );
  }
}

class _BillCard extends StatelessWidget {
  final Bill bill;
  const _BillCard({required this.bill});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      BillGenerator.formatMonth(bill.month),
                      style:
                          const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text('${AppStrings.total}: ৳${bill.total.toStringAsFixed(0)}'),
                    if (bill.paidAmount > 0)
                      Text(
                        '${AppStrings.paidAmount}: ৳${bill.paidAmount.toStringAsFixed(0)}',
                        style: const TextStyle(color: AppColors.paidColor),
                      ),
                    if (bill.due > 0)
                      Text(
                        '${AppStrings.due}: ৳${bill.due.toStringAsFixed(0)}',
                        style: const TextStyle(color: AppColors.pendingColor),
                      ),
                  ],
                ),
              ),
              Column(
                children: [
                  StatusBadge(status: bill.status),
                  const SizedBox(height: 8),
                  if (bill.isPending || bill.isPartial)
                    SizedBox(
                      width: 80,
                      height: 32,
                      child: ElevatedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CollectPaymentScreen(bill: bill),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          textStyle: const TextStyle(fontSize: 11),
                        ),
                        child: const Text(AppStrings.quickCollect),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
