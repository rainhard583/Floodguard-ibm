import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';

/// Splash screen: logo dengan glow yang berdenyut pelan, teks masuk
/// bertahap (staggered), lalu otomatis pindah ke Home (jika sudah login)
/// atau Login (jika belum) — sesuai status session Firebase yang
/// sebenarnya, bukan lagi selalu ke /login.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateNext();
  }

  Future<void> _navigateNext() async {
    // Mulai dengarkan status login pertama SEKARANG (concurrent), lalu
    // baru tunggu durasi minimum animasi splash. Dengan begitu splash
    // tidak "berkedip" terlalu cepat, tapi juga tidak menunggu lebih lama
    // dari yang perlu kalau Firebase sudah lebih dulu memberi jawaban.
    final sessionFuture = ref.read(authStateChangesProvider.future);
    await Future.delayed(const Duration(milliseconds: 2400));
    if (!mounted) return;

    final user = await sessionFuture;
    if (!mounted) return;
    context.go(user != null ? '/home' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.3),
                radius: 1.2,
                colors: [AppColors.surfaceElevated, AppColors.background],
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withOpacity(0.18),
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scale(
                        begin: const Offset(0.85, 0.85),
                        end: const Offset(1.1, 1.1),
                        duration: 1600.ms,
                        curve: Curves.easeInOut,
                      ),
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primary, AppColors.primaryDark],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.5),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.water_drop_rounded, size: 44, color: Colors.white),
                  )
                      .animate()
                      .scale(
                        begin: const Offset(0.5, 0.5),
                        end: const Offset(1, 1),
                        duration: 700.ms,
                        curve: Curves.easeOutBack,
                      )
                      .fadeIn(duration: 400.ms),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                'FloodGuard',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
              )
                  .animate()
                  .fadeIn(delay: 300.ms, duration: 500.ms)
                  .slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic),
              const SizedBox(height: 6),
              const Text(
                'Lebih Siap, Lebih Aman, Bersama.',
                style: TextStyle(color: AppColors.textSecondary),
              ).animate().fadeIn(delay: 500.ms, duration: 500.ms),
            ],
          ),
          Positioned(
            bottom: 56,
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: AppColors.primary.withOpacity(0.7),
              ),
            ),
          ).animate().fadeIn(delay: 900.ms, duration: 400.ms),
        ],
      ),
    );
  }
}
