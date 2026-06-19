import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  static const String adminEmail = 'sazzad.mzd@gmail.com';
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? _userName;
  String? get userName => _userName;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;
  bool get isAdmin => currentUser?.email == adminEmail;

  String _fallbackName(User? user) {
    final displayName = user?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    final email = user?.email?.trim();
    if (email != null && email.isNotEmpty) {
      final prefix = email.split('@').first.trim();
      if (prefix.isNotEmpty) return prefix;
    }
    return 'ব্যবহারকারী';
  }

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
      final storedName = doc.data()?['name'] as String?;
      _userName = (storedName != null && storedName.trim().isNotEmpty)
          ? storedName.trim()
          : _fallbackName(currentUser);
    } else {
      final name = _fallbackName(currentUser);
      await _db.collection('users').doc(uid).set({
        'name': name,
        'email': currentUser?.email ?? '',
        'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),
      });
      _userName = name;
    }
  }

  Future<void> updateUserName(String name) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set({
      'name': name,
      'email': currentUser?.email ?? '',
      'updatedAt': DateTime.now(),
    }, SetOptions(merge: true));
    _userName = name;
  }

  String currentDisplayName() {
    final name = _userName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return _fallbackName(currentUser);
  }

  Future<void> signOut() async {
    _userName = null;
    await _auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }
}
