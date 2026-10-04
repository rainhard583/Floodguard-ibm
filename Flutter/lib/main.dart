import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  // WidgetsFlutterBinding wajib di-init lebih dulu karena
  // Firebase.initializeApp() bersifat async dan butuh binding sebelum
  // frame pertama digambar.
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService.instance.initialize();
  runApp(const ProviderScope(child: FloodGuardApp()));
}
