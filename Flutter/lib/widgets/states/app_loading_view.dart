import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';

/// Loading state standar dipakai di seluruh app: ikon tetesan air yang
/// berdenyut pelan, opsional pesan di bawahnya. Dipakai saat menunggu data
/// dari API/Firestore/AI, sebagai pengganti CircularProgressIndicator polos.
class AppLoadingView extends StatelessWidget {
  final String? message;

  const AppLoadingView({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
            ),
            child: const Icon(Icons.water_drop_rounded, color: Colors.white, size: 28),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                begin: const Offset(0.85, 0.85),
                end: const Offset(1.05, 1.05),
                duration: 700.ms,
                curve: Curves.easeInOut,
              ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}
