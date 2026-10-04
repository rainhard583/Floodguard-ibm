import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;

/// Exception khusus auth yang isinya sudah berupa pesan siap-tampil
/// (Bahasa Indonesia, manusiawi) untuk langsung ditunjukkan ke SnackBar
/// atau dialog — UI tidak perlu tahu apa-apa soal kode error Firebase.
class AuthFailure implements Exception {
  final String message;
  const AuthFailure(this.message);

  @override
  String toString() => message;
}

/// Menerjemahkan [FirebaseAuthException.code] (dan error tak terduga
/// lainnya) menjadi [AuthFailure] dengan pesan yang bisa dipahami
/// pengguna awam.
class AuthErrorMapper {
  AuthErrorMapper._();

  static AuthFailure map(Object error) {
    if (error is FirebaseAuthException) {
      // DEBUG SEMENTARA: log code + message asli dari Firebase (tidak ada
      // password/token yang ikut ter-log). Cek tab "Logcat"/"Run" di Android
      // Studio setelah error muncul untuk melihat detail sebenarnya di balik
      // kode seperti "unknown" — biasanya message-nya menyebutkan sebab
      // aslinya (mis. CONFIGURATION_NOT_FOUND, API key invalid, dst).
      debugPrint('[AuthErrorMapper] code="${error.code}" message="${error.message}"');
      switch (error.code) {
        case 'invalid-email':
          return const AuthFailure('Format email tidak valid.');
        case 'user-disabled':
          return const AuthFailure('Akun ini telah dinonaktifkan.');
        case 'user-not-found':
          return const AuthFailure('Akun dengan email ini tidak ditemukan.');
        case 'wrong-password':
        case 'invalid-credential':
          return const AuthFailure('Email atau password salah.');
        case 'email-already-in-use':
          return const AuthFailure('Email ini sudah terdaftar. Coba masuk.');
        case 'weak-password':
          return const AuthFailure(
            'Password terlalu lemah. Gunakan minimal 8 karakter.',
          );
        case 'too-many-requests':
          return const AuthFailure(
            'Terlalu banyak percobaan. Coba lagi beberapa saat lagi.',
          );
        case 'network-request-failed':
          return const AuthFailure(
            'Tidak ada koneksi internet. Periksa jaringan Anda.',
          );
        case 'operation-not-allowed':
          return const AuthFailure(
            'Metode login ini belum diaktifkan di Firebase Console.',
          );
        default:
          return AuthFailure('Terjadi kesalahan autentikasi (${error.code}).');
      }
    }
    debugPrint('[AuthErrorMapper] non-FirebaseAuthException: ${error.runtimeType} -> $error');
    return const AuthFailure('Terjadi kesalahan yang tidak terduga. Coba lagi.');
  }
}
