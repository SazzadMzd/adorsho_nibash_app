import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/flat.dart';
import '../models/tenant.dart';
import '../models/bill.dart';
import '../models/payment.dart';
import '../models/electricity_reading.dart';
import '../models/security_transaction.dart';
import '../models/app_user_profile.dart';
import 'bill_generator.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Flats
  CollectionReference<Map<String, dynamic>> get _flats => _db.collection('flats');

  Future<DocumentReference> addFlat(Flat flat) => _flats.add(flat.toMap());
  Future<void> updateFlat(String id, Flat flat) => _flats.doc(id).update(flat.toMap());
  Future<void> deleteFlat(String id) => _flats.doc(id).delete();
  Stream<QuerySnapshot<Map<String, dynamic>>> getFlats() => _flats
      .orderBy('flatNo')
      .snapshots();
  Future<DocumentSnapshot<Map<String, dynamic>>> getFlatDoc(String id) =>
      _flats.doc(id).get();

  // Tenants
  CollectionReference<Map<String, dynamic>> get _tenants => _db.collection('tenants');

  Future<DocumentReference> addTenant(Tenant tenant) => _tenants.add(tenant.toMap());
  Future<void> updateTenant(String id, Tenant tenant) => _tenants.doc(id).update(
        tenant.toMap(),
      );
  Future<void> deleteTenant(String id) => _tenants.doc(id).delete();
  Stream<QuerySnapshot<Map<String, dynamic>>> getActiveTenants() => _tenants
      .where('status', isEqualTo: 'active')
      .snapshots();
  Stream<QuerySnapshot<Map<String, dynamic>>> getAllTenants() => _tenants
      .orderBy('name')
      .snapshots();
  Future<DocumentSnapshot<Map<String, dynamic>>> getTenantDoc(String id) =>
      _tenants.doc(id).get();

  // Bills
  CollectionReference<Map<String, dynamic>> get _bills => _db.collection('bills');

  Future<DocumentReference> addBill(Bill bill) => _bills.add(bill.toMap());
  Future<void> updateBill(String id, Bill bill) => _bills.doc(id).update(bill.toMap());
  Future<void> updateBillPartial(String id, Map<String, dynamic> data) =>
      _bills.doc(id).update(data);
  Stream<QuerySnapshot<Map<String, dynamic>>> getBillsByMonth(String month) =>
      _bills.where('month', isEqualTo: month).snapshots();
  Stream<QuerySnapshot<Map<String, dynamic>>> getPendingBills() =>
      _bills.where('status', isEqualTo: 'pending').snapshots();
  Stream<QuerySnapshot<Map<String, dynamic>>> getAllBills() =>
      _bills.orderBy('month', descending: true).snapshots();
  Future<void> deleteBill(String id) => _bills.doc(id).delete();
  Future<DocumentSnapshot<Map<String, dynamic>>> getBill(String id) =>
      _bills.doc(id).get();

  Future<QuerySnapshot<Map<String, dynamic>>> getMonthBillsSnapshot(
    String month,
  ) =>
      _bills.where('month', isEqualTo: month).get();

  // Payments
  CollectionReference<Map<String, dynamic>> get _payments => _db.collection('payments');

  Future<DocumentReference> addPayment(Payment payment) =>
      _payments.add(payment.toMap());
  Future<void> updatePayment(String id, Payment payment) =>
      _payments.doc(id).update(payment.toMap());
  Future<void> deletePayment(String id) => _payments.doc(id).delete();
  Stream<QuerySnapshot<Map<String, dynamic>>> getPaymentsByBill(String billId) =>
      _payments.where('billId', isEqualTo: billId).snapshots();
  Future<DocumentSnapshot<Map<String, dynamic>>> getPayment(String id) =>
      _payments.doc(id).get();

  // Electricity Readings
  CollectionReference<Map<String, dynamic>> get _readings =>
      _db.collection('electricity_readings');

  Future<DocumentReference> addReading(ElectricityReading reading) =>
      _readings.add(reading.toMap());
  Future<void> updateReading(String id, ElectricityReading reading) =>
      _readings.doc(id).update(reading.toMap());
  Future<void> deleteReading(String id) => _readings.doc(id).delete();
  Stream<QuerySnapshot<Map<String, dynamic>>> getReadingsByFlat(String flatId) =>
      _readings.where('flatId', isEqualTo: flatId).orderBy('month', descending: true).snapshots();

  Future<DocumentSnapshot<Map<String, dynamic>>?> getLastReading(
    String flatId,
  ) =>
      _readings
          .where('flatId', isEqualTo: flatId)
          .orderBy('month', descending: true)
          .limit(1)
          .get()
          .then((snap) => snap.docs.isNotEmpty ? snap.docs.first : null);

  Future<QuerySnapshot<Map<String, dynamic>>> getReadingsByMonth(
    String month,
  ) =>
      _readings.where('month', isEqualTo: month).get();

  // Security Transactions
  CollectionReference<Map<String, dynamic>> get _securityTransactions =>
      _db.collection('security_transactions');

  Future<DocumentReference> addSecurityTransaction(
    SecurityTransaction transaction,
  ) =>
      _securityTransactions.add(transaction.toMap());
  Stream<QuerySnapshot<Map<String, dynamic>>> getSecurityByTenant(
    String tenantId,
  ) =>
      _securityTransactions
          .where('tenantId', isEqualTo: tenantId)
          .orderBy('date')
          .snapshots();

  // Settings
  CollectionReference<Map<String, dynamic>> get _settings =>
      _db.collection('settings');

  Future<DocumentSnapshot<Map<String, dynamic>>> getSettings() =>
      _settings.doc('app_settings').get();

  Future<void> updateSettings(Map<String, dynamic> data) =>
      _settings.doc('app_settings').set(data, SetOptions(merge: true));

  // Users
  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  Future<DocumentSnapshot<Map<String, dynamic>>> getUser(String uid) =>
      _users.doc(uid).get();

  Future<void> setUser(String uid, Map<String, dynamic> data) =>
      _users.doc(uid).set(data, SetOptions(merge: true));

  Stream<QuerySnapshot<Map<String, dynamic>>> getUsers() => _users
      .orderBy('name')
      .snapshots();

  Future<DocumentReference<Map<String, dynamic>>> addUser(
    AppUserProfile user,
  ) =>
      _users.add(user.toMap());

  Future<void> updateUser(String id, AppUserProfile user) =>
      _users.doc(id).set(user.toMap(), SetOptions(merge: true));

  Future<void> deleteUser(String id) => _users.doc(id).delete();

  // Auto-generate bills
  Future<void> generateBillsForMonth(
    String month,
    List<Tenant> activeTenants,
    Map<String, Flat> flatMap,
  ) async {
    final previousMonth = BillGenerator.previousMonth(month);
    final previousBillsSnap = await getMonthBillsSnapshot(previousMonth);
    final previousBillsByFlatId = {
      for (final d in previousBillsSnap.docs)
        Bill.fromMap(d.id, d.data()).flatId: Bill.fromMap(d.id, d.data()),
    };
    final bills = BillGenerator.createBills(
      month,
      activeTenants,
      flatMap,
      null,
      previousBillsByFlatId,
    );
    final batch = _db.batch();

    for (final bill in bills) {
      final docRef = _bills.doc();
      batch.set(docRef, bill.toMap());
    }

    await batch.commit();
  }
}
