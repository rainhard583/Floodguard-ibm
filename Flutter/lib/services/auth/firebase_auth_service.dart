import 'package:firebase_auth/firebase_auth.dart';

/// Lapisan paling bawah (service) yang berbicara langsung ke Firebase SDK.
/// Sengaja dibuat sangat tipis — tidak ada mapping error atau logic bisnis
/// di sini, itu tugas [AuthRepository]. Dipisah begini supaya repository
/// (dan lewat itu, seluruh app) tidak bergantung langsung ke
/// `FirebaseAuth.instance`, dan lebih mudah di-mock saat testing.
class FirebaseAuthService {
  final FirebaseAuth _auth;

  FirebaseAuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  /// Stream perubahan status login (login, logout, token expired, dll).
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (displayName.trim().isNotEmpty) {
      await credential.user?.updateDisplayName(displayName.trim());
      await credential.user?.reload();
    }
    return credential;
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() => _auth.signOut();
}
