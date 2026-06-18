import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/flat.dart';
import '../models/tenant.dart';
import '../models/bill.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';

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
