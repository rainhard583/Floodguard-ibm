import '../core/errors/auth_error_mapper.dart';
import '../models/user_model.dart';
import '../services/auth/firebase_auth_service.dart';

/// Menjembatani provider (state management) dengan [FirebaseAuthService].
/// Semua exception mentah dari Firebase ditangkap & diterjemahkan di sini
/// lewat [AuthErrorMapper], supaya layer provider/UI hanya perlu menangani
/// satu jenis exception ([AuthFailure]) dengan pesan yang sudah siap tampil,
/// dan bekerja dengan [UserModel] alih-alih tipe [User] milik Firebase.
class AuthRepository {
  final FirebaseAuthService _authService;

  AuthRepository({FirebaseAuthService? authService})
      : _authService = authService ?? FirebaseAuthService();

  Stream<UserModel?> authStateChanges() {
    return _authService.authStateChanges().map(
          (user) => user == null ? null : UserModel.fromFirebaseUser(user),
        );
  }

  UserModel? get currentUser {
    final user = _authService.currentUser;
    return user == null ? null : UserModel.fromFirebaseUser(user);
  }

  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _authService.signIn(email: email, password: password);
      final user = credential.user;
      if (user == null) throw const AuthFailure('Gagal masuk. Coba lagi.');
      return UserModel.fromFirebaseUser(user);
    } catch (e) {
      throw AuthErrorMapper.map(e);
    }
  }

  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _authService.register(
        email: email,
        password: password,
        displayName: name,
      );
      final user = credential.user;
      if (user == null) throw const AuthFailure('Gagal mendaftar. Coba lagi.');
      final userModel = UserModel.fromFirebaseUser(user);

      // Firebase otomatis men-sign-in user baru saat
      // createUserWithEmailAndPassword() sukses. Sesuai keputusan produk:
      // setelah daftar, user tetap harus login manual (bukan langsung
      // masuk Home) — jadi sign-out lagi di sini supaya status auth
      // kembali "belum login".
      await _authService.signOut();

      return userModel;
    } catch (e) {
      throw AuthErrorMapper.map(e);
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _authService.sendPasswordResetEmail(email);
    } catch (e) {
      throw AuthErrorMapper.map(e);
    }
  }

  Future<void> signOut() => _authService.signOut();
}
