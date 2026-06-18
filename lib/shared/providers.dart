import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/flat.dart';
import '../models/tenant.dart';
import '../models/bill.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/bill_generator.dart';

final firestoreServiceProvider = Provider<FirestoreService>((ref) => FirestoreService());

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StreamProvider<dynamic>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final flatListProvider = StreamProvider<List<Flat>>((ref) {
  final service = ref.watch(firestoreServiceProvider);
  return service.getFlats().map((snap) =>
      snap.docs.map((d) => Flat.fromMap(d.id, d.data())).toList());
});

final tenantListProvider = StreamProvider<List<Tenant>>((ref) {
  final service = ref.watch(firestoreServiceProvider);
  return service.getAllTenants().map((snap) =>
      snap.docs.map((d) => Tenant.fromMap(d.id, d.data())).toList());
});

final activeTenantListProvider = StreamProvider<List<Tenant>>((ref) {
  final service = ref.watch(firestoreServiceProvider);
  return service.getActiveTenants().map((snap) =>
      snap.docs.map((d) => Tenant.fromMap(d.id, d.data())).toList());
});

final billsProvider = StreamProvider<List<Bill>>((ref) {
  final service = ref.watch(firestoreServiceProvider);
  return service.getAllBills().map((snap) =>
      snap.docs.map((d) => Bill.fromMap(d.id, d.data())).toList());
});

final billByMonthProvider = StreamProvider.family<List<Bill>, String>((ref, month) {
  final service = ref.watch(firestoreServiceProvider);
  return service.getBillsByMonth(month).map((snap) =>
      snap.docs.map((d) => Bill.fromMap(d.id, d.data())).toList());
});

final billGenerationProvider = FutureProvider.autoDispose<void>((ref) async {
  final service = ref.watch(firestoreServiceProvider);
  final flatList = await ref.watch(flatListProvider.future);
  final tenants = await ref.watch(activeTenantListProvider.future);
  final flatMap = {for (final f in flatList) f.id: f};
  final month = BillGenerator.currentMonth();
  await service.generateBillsForMonth(month, tenants, flatMap);
});
