import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import 'monthly_report_screen.dart';

class ReportListScreen extends StatelessWidget {
  const ReportListScreen({super.key});

  void _openMonthlyReport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MonthlyReportScreen()),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('শীঘ্রই আসছে'),
        backgroundColor: AppColors.info,
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.reports)),
      body: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - value)),
            child: child,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ReportCard(
              icon: Icons.calendar_month,
              label: AppStrings.monthlyReport,
              color: AppColors.primary,
              onTap: () => _openMonthlyReport(context),
            ),
            _ReportCard(
              icon: Icons.person,
              label: AppStrings.tenantReport,
              color: AppColors.info,
              onTap: () => _openMonthlyReport(context),
            ),
            _ReportCard(
              icon: Icons.apartment,
              label: AppStrings.flatReport,
              color: AppColors.accent,
              onTap: () => _openMonthlyReport(context),
            ),
            _ReportCard(
              icon: Icons.savings,
              label: AppStrings.depositReport,
              color: AppColors.success,
              onTap: () => _showComingSoon(context),
            ),
            _ReportCard(
              icon: Icons.payment,
              label: AppStrings.paymentReport,
              color: AppColors.warning,
              onTap: () => _showComingSoon(context),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'এক্সপোর্ট',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            _ReportCard(
              icon: Icons.picture_as_pdf,
              label: AppStrings.exportPdf,
              color: AppColors.pendingColor,
              onTap: () => _openMonthlyReport(context),
            ),
            _ReportCard(
              icon: Icons.table_chart,
              label: AppStrings.exportExcel,
              color: AppColors.paidColor,
              onTap: () => _openMonthlyReport(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ReportCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
