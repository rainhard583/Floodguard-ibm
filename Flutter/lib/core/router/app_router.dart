import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../screens/splash/splash_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/map/map_screen.dart';
import '../../screens/detection/detection_screen.dart';
import '../../screens/history/history_screen.dart';
import '../../screens/notifications/notifications_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../widgets/main_shell.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Router berupa Provider (bukan variabel top-level biasa) supaya auth
/// guard di `redirect` bisa membaca status login lewat Riverpod. GoRouter
/// dibuat SEKALI SAJA — perubahan status login tidak membuat GoRouter baru,
/// melainkan memicu `refreshListenable` yang menyuruh GoRouter mengevaluasi
/// ulang `redirect` saja, supaya stack navigasi tidak ke-reset tiap kali
/// user login/logout.
final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _AuthRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final isSplash = loc == '/splash';
      final isAuthPage = loc == '/login' || loc == '/register';

      // Splash mengurus navigasi awalnya sendiri (menunggu animasi +
      // status login pertama), jangan diintervensi oleh redirect di sini.
      if (isSplash) return null;

      // Selama Register berlangsung, status login sempat "kedip" (login
      // sesaat lalu sign-out lagi) — lihat authFlowGuardProvider. Jangan
      // redirect dulu selama window ini, navigasi akhir dilakukan manual
      // oleh RegisterScreen setelah semua proses benar-benar selesai.
      if (ref.read(authFlowGuardProvider)) return null;

      // ref.read (bukan watch) karena kita membaca nilai TERKINI saat
      // redirect dipanggil. Ini sekarang AMAN dibaca langsung setelah
      // refreshNotifier memberi tahu — lihat penjelasan di
      // _AuthRefreshNotifier di bawah.
      final authState = ref.read(authStateChangesProvider);

      // Selama status login belum diketahui (baru buka app, stream belum
      // sempat emit nilai pertama), jangan redirect dulu — cegah
      // "flicker" ke /login sebelum sempat dicek.
      if (authState.isLoading) return null;

      final loggedIn = authState.valueOrNull != null;

      if (!loggedIn && !isAuthPage) {
        debugPrint('[AppRouter] unauthenticated -> /login');
        return '/login';
      }
      if (loggedIn && isAuthPage) {
        debugPrint('[AppRouter] authenticated -> /home');
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/home', builder: (context, state) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/map', builder: (context, state) => const MapScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/detection', builder: (context, state) => const DetectionScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/history', builder: (context, state) => const HistoryScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen())],
          ),
        ],
      ),
    ],
  );
});

/// Menjembatani perubahan [authStateChangesProvider] ke GoRouter lewat
/// `refreshListenable`.
///
/// PENTING — ini perbaikan dari bug sebelumnya: versi lama membuat
/// SUBSCRIPTION STREAM TERPISAH (`authRepository.authStateChanges()`
/// dipanggil ulang di sini, independen dari yang dipakai
/// `authStateChangesProvider`). Dua subscription terpisah ke stream yang
/// secara konsep "sama" TIDAK dijamin urutan microtask-nya oleh Dart —
/// akibatnya `notifyListeners()` di sini bisa terpanggil SEBELUM
/// `authStateChangesProvider` sempat ter-update ke nilai baru. Saat itu
/// terjadi, `redirect` di atas membaca status login yang masih basi
/// (null) tepat setelah register/login sukses, GoRouter memutuskan tidak
/// perlu pindah halaman, dan momen itu tidak pernah terulang lagi
/// (refreshListenable sudah terlanjur "dipakai") — makanya user macet di
/// Register/Login walau Firebase sudah sukses bikin akun.
///
/// Perbaikannya: dengarkan PROVIDER-nya langsung lewat `ref.listen`,
/// bukan stream mentahnya lagi. Dengan begitu `notifyListeners()` DIJAMIN
/// baru terpanggil SETELAH nilai `authStateChangesProvider` benar-benar
/// ter-update — jadi `ref.read(authStateChangesProvider)` di `redirect`
/// selalu membaca nilai yang sudah segar, bukan basi.
class _AuthRefreshNotifier extends ChangeNotifier {
  late final ProviderSubscription<AsyncValue<UserModel?>> _subscription;

  _AuthRefreshNotifier(Ref ref) {
    _subscription = ref.listen<AsyncValue<UserModel?>>(
      authStateChangesProvider,
      (previous, next) => notifyListeners(),
    );
  }

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}
