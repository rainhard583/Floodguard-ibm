import 'package:firebase_auth/firebase_auth.dart';

/// Representasi user FloodGuard di level aplikasi. UI dan provider bekerja
/// dengan tipe ini, bukan langsung dengan [User] dari Firebase SDK, supaya
/// layer di atas repository tidak terikat ke Firebase secara langsung.
/// Field akan bertambah mulai Phase 3 saat data profil disimpan di
/// Firestore (mis. lokasi favorit, nomor telepon darurat, dll).
class UserModel {
  final String uid;
  final String? email;
  final String? displayName;
  final bool emailVerified;

  const UserModel({
    required this.uid,
    this.email,
    this.displayName,
    this.emailVerified = false,
  });

  factory UserModel.fromFirebaseUser(User user) {
    return UserModel(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      emailVerified: user.emailVerified,
    );
  }
}
