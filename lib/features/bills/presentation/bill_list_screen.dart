import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/flat.dart';
import '../../../models/bill.dart';
import '../../../services/bill_generator.dart';
import '../../../shared/providers.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/animations.dart';
import '../../payments/presentation/collect_payment_screen.dart';
import 'bill_form_screen.dart';
import 'bill_generation_screen.dart';
import '../../receipts/presentation/receipt_view_screen.dart';

class BillListScreen extends ConsumerStatefulWidget {
  final String? initialMonth;
  const BillListScreen({super.key, this.initialMonth});

  @override
  ConsumerState<BillListScreen> createState() => _BillListScreenState();
}

class _BillListScreenState extends ConsumerState<BillListScreen> {
  late String _selectedMonth;
  late int _selectedYear;
  late int _selectedMonthNum;

  @override
  void initState() {
    super.initState();
    _selectedMonth = widget.initialMonth ?? BillGenerator.currentMonth();
    final parts = _selectedMonth.split('-');
    _selectedYear = int.parse(parts[0]);
    _selectedMonthNum = int.parse(parts[1]);
  }

  Future<void> _showMonthPicker() async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _MonthYearPickerDialog(
        initialYear: _selectedYear,
        initialMonth: _selectedMonthNum,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        if (result == 'all') {
          _selectedMonth = 'all';
        } else {
          _selectedYear = int.parse(result.split('-')[0]);
          _selectedMonthNum = int.parse(result.split('-')[1]);
          _selectedMonth = result;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final billsAsync = _selectedMonth == 'all'
        ? ref.watch(billsProvider)
        : ref.watch(billByMonthProvider(_selectedMonth));
    final flatsAsync = ref.watch(flatListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.bills),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: AppStrings.generateBills,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BillGenerationScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'মাস নির্বাচন',
            onPressed: _showMonthPicker,
          ),
        ],
      ),
      body: flatsAsync.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => Center(child: Text('$e')),
        data: (flats) {
          final flatMap = {for (final flat in flats) flat.id: flat};
          return billsAsync.when(
            loading: () => const LoadingWidget(),
            error: (e, _) => Center(child: Text('$e')),
            data: (bills) {
              if (bills.isEmpty) {
                return EmptyState(icon: Icons.receipt_long, message: AppStrings.noBills);
              }
              return ListView.builder(
                itemCount: bills.length,
                itemBuilder: (_, i) => AnimatedListItem(
                  index: i,
                  child: _BillCard(
                    bill: bills[i],
                    flatLabel: _flatLabel(flatMap[bills[i].flatId]),
                    openReceiptView: bills[i].isPaid || bills[i].isPartial,
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

class _BillCard extends StatelessWidget {
  final Bill bill;
  final String flatLabel;
  final bool openReceiptView;
  const _BillCard({
    required this.bill,
    required this.flatLabel,
    required this.openReceiptView,
  });

  void _openDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => openReceiptView
            ? ReceiptViewScreen(bill: bill)
            : BillFormScreen(bill: bill, updateOnly: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => _openDetail(context),
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
                    if (flatLabel.isNotEmpty)
                      Text(
                        flatLabel,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    if (flatLabel.isNotEmpty) const SizedBox(height: 2),
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

String _flatLabel(Flat? flat) {
  if (flat == null) return '';
  if (flat.floor.isNotEmpty) return '${flat.floor} - ${flat.flatNo}';
  return flat.flatNo;
}

class _MonthYearPickerDialog extends StatefulWidget {
  final int initialYear;
  final int initialMonth;
  const _MonthYearPickerDialog({required this.initialYear, required this.initialMonth});

  @override
  State<_MonthYearPickerDialog> createState() => _MonthYearPickerDialogState();
}

class _MonthYearPickerDialogState extends State<_MonthYearPickerDialog> {
  late int _year;
  late int _selectedMonth;

  static const _months = [
    'জানু', 'ফেব্রু', 'মার্চ', 'এপ্রি',
    'মে', 'জুন', 'জুলা', 'আগস্ট',
    'সেপ্টে', 'অক্টো', 'নভে', 'ডিসে',
  ];

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear;
    _selectedMonth = widget.initialMonth;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() => _year--),
          ),
          Text('$_year', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(() => _year++),
          ),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, 'all'),
                icon: const Icon(Icons.list, size: 18),
                label: const Text('সব বিল', style: TextStyle(fontSize: 14)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: 12,
              itemBuilder: (_, i) {
                final month = i + 1;
                final isSelected = month == _selectedMonth;
                return ElevatedButton(
                  onPressed: () => setState(() => _selectedMonth = month),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSelected ? Theme.of(context).primaryColor : null,
                    foregroundColor: isSelected ? Colors.white : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: isSelected
                          ? BorderSide.none
                          : BorderSide(color: Colors.grey.shade300),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(
                    _months[i],
                    style: const TextStyle(fontSize: 14),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('বাতিল'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(
            context,
            '$_year-${_selectedMonth.toString().padLeft(2, '0')}',
          ),
          child: const Text('নির্বাচন'),
        ),
      ],
    );
  }
}
