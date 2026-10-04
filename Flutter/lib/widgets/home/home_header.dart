import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../screens/notifications/notifications_screen.dart';

class HomeHeader extends StatelessWidget {
  final UserModel? user;
  const HomeHeader({super.key, required this.user});

  String get _greeting {
    final name = user?.displayName;
    if (name != null && name.trim().isNotEmpty) return 'Selamat datang, ${name.trim()}';
    final email = user?.email;
    if (email != null && email.contains('@')) return 'Selamat datang, ${email.split('@').first}';
    return 'Lebih aman, lebih siap.';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF56B8FF), AppColors.primary],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: AppColors.primary.withValues(alpha: .20), blurRadius: 16, offset: const Offset(0, 8)),
            ],
          ),
          child: const Icon(Icons.waves_rounded, color: Colors.white, size: 28),
        ).animate().fadeIn().scale(),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, letterSpacing: -.7),
                  children: [
                    TextSpan(text: 'Flood', style: TextStyle(color: AppColors.textPrimary)),
                    TextSpan(text: 'Guard', style: TextStyle(color: AppColors.primary)),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(_greeting, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
            ],
          ),
        ).animate().fadeIn().slideX(begin: -.04, end: 0),
        ValueListenableBuilder<int>(
          valueListenable: notificationUnreadCount,
          builder: (context, unread, _) => _CircleIconButton(
            icon: unread > 0
                ? Icons.notifications_active_rounded
                : Icons.notifications_none_rounded,
            badge: unread > 0,
            onTap: () {
              notificationUnreadCount.value = 0;
              context.push('/notifications');
            },
          ),
        ),
        const SizedBox(width: 8),
        _CircleIconButton(icon: Icons.person_outline_rounded, onTap: () => context.go('/profile')),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool badge;
  const _CircleIconButton({required this.icon, required this.onTap, this.badge = false});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.white.withValues(alpha: .88),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.2),
                boxShadow: [BoxShadow(color: const Color(0xFF7DA6D4).withValues(alpha: .14), blurRadius: 14, offset: const Offset(0, 6))],
              ),
              child: Icon(icon, color: AppColors.textPrimary, size: 23),
            ),
          ),
        ),
        if (badge)
          Positioned(right: 1, top: 1, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFFF5A63), shape: BoxShape.circle))),
      ],
    ).animate().fadeIn();
  }
}
