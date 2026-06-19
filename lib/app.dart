import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_strings.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/flats/presentation/flat_list_screen.dart';
import 'features/tenants/presentation/tenant_list_screen.dart';
import 'features/bills/presentation/bill_list_screen.dart';
import 'features/reports/presentation/report_list_screen.dart';
import 'shared/providers.dart';
import 'shared/widgets/app_brand_mark.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  @override
  void initState() {
    super.initState();
    ref.read(authServiceProvider).init();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      title: AppStrings.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: authState.when(
        data: (user) => user != null ? const MainShell() : const LoginScreen(),
        loading: () => const _SplashScreen(),
        error: (_, _) => const LoginScreen(),
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF7FBF4),
              Color(0xFFEAF4E4),
              Color(0xFFFFF7E8),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -40,
              right: -20,
              child: _GlowBlob(color: AppColors.accent.withValues(alpha: 0.16), size: 160),
            ),
            Positioned(
              bottom: -30,
              left: -30,
              child: _GlowBlob(color: AppColors.primary.withValues(alpha: 0.14), size: 200),
            ),
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.92, end: 1),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppBrandMark(size: 112),
                    const SizedBox(height: 28),
                    Text(
                      'রেন্ট ম্যানেজমেন্ট',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 24),
                    const SizedBox(
                      width: 34,
                      height: 34,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 40,
            spreadRadius: 10,
          ),
        ],
      ),
    );
  }
}

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    BillListScreen(),
    TenantListScreen(),
    FlatListScreen(),
    ReportListScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: AppStrings.dashboard,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: AppStrings.bills,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: AppStrings.tenants,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.apartment),
            label: AppStrings.flats,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: AppStrings.reports,
          ),
        ],
      ),
    );
  }
}
