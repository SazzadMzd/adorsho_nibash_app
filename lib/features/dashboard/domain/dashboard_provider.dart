import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/flat.dart';
import '../../../models/tenant.dart';
import '../../../models/bill.dart';

final dashboardDataProvider = FutureProvider<DashboardData>((ref) async {
  final db = FirebaseFirestore.instance;

  final flatsSnap = await db.collection('flats').get();
  final tenantsSnap =
      await db.collection('tenants').where('status', isEqualTo: 'active').get();
  final billsSnap = await db.collection('bills').get();

  final flats = flatsSnap.docs
      .map((d) => Flat.fromMap(d.id, d.data()))
      .where((f) => f.isActive)
      .toList();
  final activeTenants =
      tenantsSnap.docs.map((d) => Tenant.fromMap(d.id, d.data())).toList();
  final bills =
      billsSnap.docs.map((d) => Bill.fromMap(d.id, d.data())).toList();

  final totalDeposit =
      activeTenants.fold<double>(0, (total, t) => total + t.securityDeposit);

  final currentMonth = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
  final monthBills = bills.where((b) => b.month == currentMonth).toList();
  final totalBills = monthBills.fold<double>(0, (t, b) => t + b.total);
  final totalPaid = monthBills.fold<double>(0, (t, b) => t + b.paidAmount);
  final paidCount = monthBills.where((b) => b.isPaid).length;
  final pendingCount = monthBills.where((b) => b.isPending).length;
  final partialCount = monthBills.where((b) => b.isPartial).length;

  return DashboardData(
    totalFlats: flats.length,
    activeTenants: activeTenants.length,
    monthBills: monthBills.length,
    totalBills: totalBills,
    totalPaid: totalPaid,
    totalPending: totalBills - totalPaid,
    paidCount: paidCount,
    pendingCount: pendingCount,
    partialCount: partialCount,
    totalDeposit: totalDeposit,
  );
});

class DashboardData {
  final int totalFlats;
  final int activeTenants;
  final int monthBills;
  final double totalBills;
  final double totalPaid;
  final double totalPending;
  final int paidCount;
  final int pendingCount;
  final int partialCount;
  final double totalDeposit;

  DashboardData({
    required this.totalFlats,
    required this.activeTenants,
    required this.monthBills,
    required this.totalBills,
    required this.totalPaid,
    required this.totalPending,
    required this.paidCount,
    required this.pendingCount,
    required this.partialCount,
    required this.totalDeposit,
  });
}
