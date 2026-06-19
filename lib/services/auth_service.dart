import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? _userName;
  String? get userName => _userName;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;

  Future<void> init() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _initUserDoc(user.uid);
    }
  }

  Future<UserCredential> signIn(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _initUserDoc(cred.user!.uid);
    return cred;
  }

  Future<void> _initUserDoc(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) {
      _userName = doc.data()?['name'] as String? ?? 'ব্যবহারকারী';
    } else {
      final name = currentUser?.displayName ?? 'ব্যবহারকারী';
      await _db.collection('users').doc(uid).set({
        'name': name,
        'email': currentUser?.email ?? '',
        'createdAt': DateTime.now(),
      });
      _userName = name;
    }
  }

  Future<void> updateUserName(String name) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).update({'name': name});
    _userName = name;
  }

  Future<void> signOut() async {
    _userName = null;
    await _auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }
}
