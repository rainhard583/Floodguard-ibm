import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'services/floodguard_settings.dart';

class FloodGuardApp extends ConsumerWidget {
  const FloodGuardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return AnimatedBuilder(
      animation: FloodGuardSettings.instance,
      builder: (context, _) {
        final mode = FloodGuardSettings.instance.themeMode;
        return MaterialApp.router(
          title: 'FloodGuard',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode == 'Gelap'
              ? ThemeMode.dark
              : mode == 'Mengikuti sistem'
                  ? ThemeMode.system
                  : ThemeMode.light,
          routerConfig: router,
        );
      },
    );
  }
}
