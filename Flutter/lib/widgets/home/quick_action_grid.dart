import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';

/// Data satu Quick Action (dipisah dari widget-nya supaya HomeScreen bisa
/// mendefinisikan daftar aksi tanpa peduli detail rendering-nya).
class QuickAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const QuickAction({required this.icon, required this.label, required this.onTap});
}

/// Grid Quick Actions di Home (Deteksi Banjir, Peta Banjir, Lapor Banjir,
/// Emergency). Menggunakan rute yang SUDAH ADA (`/detection`, `/map`) bila
/// tersedia; untuk aksi yang belum punya layar sungguhan, `onTap` di-supply
/// oleh HomeScreen memakai [showComingSoonSheet] — bukan crash, bukan pura-
/// pura fitur sudah ada.
class QuickActionGrid extends StatelessWidget {
  final List<QuickAction> actions;

  const QuickActionGrid({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.4,
      ),
      itemBuilder: (context, index) {
        final action = actions[index];
        return _QuickActionCard(action: action)
            .animate()
            .fadeIn(delay: Duration(milliseconds: 60 * index))
            .slideY(begin: 0.08, end: 0);
      },
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final QuickAction action;
  const _QuickActionCard({required this.action});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: action.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.15),
                ),
                child: Icon(action.icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  action.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
