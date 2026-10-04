import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/states/app_error_view.dart';
import '../../widgets/states/app_loading_view.dart';
import 'settings_screen.dart';

/// Layar Profil. Sebelumnya PlaceholderScreen — diganti karena Logout
/// adalah salah satu target eksplisit Phase 2 dan butuh UI nyata untuk
/// dites (data user, tombol keluar). Fitur lain (lokasi favorit,
/// pengaturan) masih placeholder ringan, menunggu phase-nya masing-masing.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const _photoKey = 'floodguard_profile_photo_path';
  String? _photoPath;
  bool _loadingPhoto = true;

  @override
  void initState() {
    super.initState();
    _loadProfilePhoto();
  }

  Future<void> _loadProfilePhoto() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_photoKey);
    if (!mounted) return;
    setState(() {
      _photoPath = path;
      _loadingPhoto = false;
    });
  }

  Future<void> _changeProfilePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
      maxHeight: 1200,
    );
    if (picked == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_photoKey, picked.path);
    if (!mounted) return;
    setState(() => _photoPath = picked.path);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Foto profil berhasil diubah.')),
    );
  }

  Future<void> _removeProfilePhoto() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_photoKey);
    if (!mounted) return;
    setState(() => _photoPath = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Foto profil dihapus.')),
    );
  }

  Future<void> _showPhotoOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 18),
              const Align(alignment: Alignment.centerLeft, child: Text('Foto profil', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              const SizedBox(height: 10),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.photo_library_outlined)),
                title: const Text('Pilih dari galeri'),
                subtitle: const Text('Gunakan foto yang tersimpan di HP'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _changeProfilePhoto();
                },
              ),
              if (_photoPath != null)
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.delete_outline)),
                  title: const Text('Hapus foto profil'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _removeProfilePhoto();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Keluar', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Anda yakin ingin keluar dari akun ini?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Keluar', style: TextStyle(color: AppColors.riskBahaya)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      // Setelah signOut, authStateChangesProvider akan emit null dan auth
      // guard di appRouter otomatis mengarahkan kembali ke /login.
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateChangesProvider);

    return Scaffold(
      body: SafeArea(
        child: authState.when(
          loading: () => const AppLoadingView(),
          error: (error, _) => AppErrorView(
            message: 'Gagal memuat data akun.',
            onRetry: () => ref.invalidate(authStateChangesProvider),
          ),
          data: (user) {
            if (user == null) {
              // Praktis tidak pernah terlihat — auth guard di router akan
              // langsung memindahkan ke /login begitu user null.
              return const SizedBox.shrink();
            }

            final initial = (user.displayName?.isNotEmpty == true
                    ? user.displayName!
                    : (user.email ?? '?'))[0]
                .toUpperCase();

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profil',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  ).animate().fadeIn().slideY(begin: 0.15, end: 0),
                  const SizedBox(height: 24),
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _showPhotoOptions,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.35),
                                      blurRadius: 24,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: _loadingPhoto
                                      ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                                      : (_photoPath != null && File(_photoPath!).existsSync())
                                          ? Image.file(File(_photoPath!), fit: BoxFit.cover)
                                          : Center(
                                              child: Text(
                                                initial,
                                                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
                                              ),
                                            ),
                                ),
                              ),
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, border: Border.all(color: AppColors.background, width: 3)),
                                  child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 17),
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn().scale(
                              begin: const Offset(0.7, 0.7),
                              end: const Offset(1, 1),
                              curve: Curves.easeOutBack,
                            ),
                        const SizedBox(height: 16),
                        Text(
                          user.displayName?.isNotEmpty == true ? user.displayName! : 'Pengguna FloodGuard',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email ?? '-',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 100.ms),
                  const SizedBox(height: 32),
                  const _ProfileMenuTile(
                    icon: Icons.location_on_outlined,
                    label: 'Lokasi Favorit',
                    subtitle: 'Kelola lokasi yang dipantau FloodGuard',
                  ),
                  _ProfileMenuTile(
                    icon: Icons.settings_outlined,
                    label: 'Pengaturan',
                    subtitle: 'Notifikasi, lokasi, cuaca, peta, dan AI',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmLogout(context, ref),
                      icon: const Icon(Icons.logout_rounded, color: AppColors.riskBahaya),
                      label: const Text('Keluar', style: TextStyle(color: AppColors.riskBahaya)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        side: const BorderSide(color: AppColors.riskBahaya),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ).animate().fadeIn(delay: 200.ms),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProfileMenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;

  const _ProfileMenuTile({required this.icon, required this.label, required this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 150.ms),
    );
  }
}
