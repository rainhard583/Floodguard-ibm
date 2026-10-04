import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/errors/auth_error_mapper.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';

/// Instance tunggal [AuthRepository] untuk seluruh app.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// Stream status login user (null = belum login). Dipakai oleh
/// [SplashScreen] untuk cek session awal, dan oleh `appRouter` sebagai
/// dasar auth guard. AsyncValue-nya otomatis menangani loading state di
/// awal (sebelum Firebase sempat memberi tahu status login) dan error
/// state bila stream gagal.
final authStateChangesProvider = StreamProvider<UserModel?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

/// Controller untuk aksi-aksi auth: login, register, lupa password,
/// logout. State-nya `AsyncValue<void>` supaya UI (mis. [PrimaryButton])
/// bisa langsung tahu kapan menampilkan loading tanpa perlu variabel
/// `_loading` lokal terpisah di tiap screen.
/// True selagi ada aksi auth yang SENGAJA membuat status login berubah
/// sementara (Register: Firebase otomatis sign-in user baru, lalu kita
/// sign-out lagi supaya user login manual). `appRouter` membaca flag ini
/// untuk MENAHAN diri dari redirect otomatis selama window transisi ini,
/// supaya user tidak melihat "kilatan" pindah ke Home sebelum akhirnya
/// balik ke Login.
final authFlowGuardProvider = StateProvider<bool>((ref) => false);

class AuthController extends StateNotifier<AsyncValue<void>> {
  final AuthRepository _repository;
  final Ref _ref;

  AuthController(this._repository, this._ref) : super(const AsyncData(null));

  Future<bool> signIn({required String email, required String password}) async {
    debugPrint('[AuthProvider] signIn started');
    state = const AsyncLoading();
    try {
      await _repository.signIn(email: email, password: password);
      debugPrint('[AuthProvider] signIn success');
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      debugPrint('[AuthProvider] signIn failed: $e');
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    debugPrint('[AuthProvider] register started');
    state = const AsyncLoading();
    _ref.read(authFlowGuardProvider.notifier).state = true;
    try {
      await _repository.register(name: name, email: email, password: password);
      debugPrint('[AuthProvider] register success');
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      debugPrint('[AuthProvider] register failed: $e');
      state = AsyncError(e, st);
      return false;
    } finally {
      _ref.read(authFlowGuardProvider.notifier).state = false;
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    state = const AsyncLoading();
    try {
      await _repository.sendPasswordResetEmail(email);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<void> signOut() async {
    await _repository.signOut();
  }

  /// Pesan error siap-tampil dari state saat ini (null bila tidak ada
  /// error atau errornya bukan [AuthFailure]).
  String? get errorMessage {
    final error = state.error;
    if (error == null) return null;
    return error is AuthFailure ? error.message : 'Terjadi kesalahan. Coba lagi.';
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  return AuthController(ref.watch(authRepositoryProvider), ref);
});
