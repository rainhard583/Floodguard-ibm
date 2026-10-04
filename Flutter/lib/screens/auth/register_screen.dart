import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/primary_button.dart';

/// Layar registrasi. Sudah tersambung ke Firebase Authentication asli
/// lewat [authControllerProvider]. Setelah register berhasil, user
/// SENGAJA di-sign-out lagi (lihat AuthRepository.register()) dan
/// diarahkan manual ke /login — bukan otomatis masuk ke Home — supaya
/// user login ulang dengan akun yang baru dibuat.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    // Lihat penjelasan lengkap di login_screen.dart — bug yang sama:
    // teks SnackBar tidak diberi warna eksplisit, jadi mewarisi warna gelap
    // default Material 3 yang tidak kontras dengan background gelap kita.
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.surfaceElevated,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showMessage('Semua field wajib diisi.');
      return;
    }
    if (password.length < 8) {
      _showMessage('Password minimal 8 karakter.');
      return;
    }
    if (password != confirm) {
      _showMessage('Konfirmasi password tidak cocok.');
      return;
    }

    final controller = ref.read(authControllerProvider.notifier);
    final success = await controller.register(name: name, email: email, password: password);
    if (!mounted) return;
    if (success) {
      _showMessage('Registrasi berhasil! Silakan login dengan akun Anda.');
      context.go('/login');
    } else {
      _showMessage(controller.errorMessage ?? 'Gagal mendaftar. Coba lagi.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authControllerProvider).isLoading;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.6),
            radius: 1.3,
            colors: [AppColors.surfaceElevated, AppColors.background],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  'Buat Akun Baru',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2, end: 0),
                const SizedBox(height: 6),
                const Text(
                  'Daftar untuk mulai memantau risiko banjir di sekitar Anda.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: 28),
                AppTextField(
                  controller: _nameController,
                  label: 'Nama Lengkap',
                  hint: 'Nama Anda',
                  prefixIcon: Icons.person_outline_rounded,
                ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.15, end: 0),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'nama@email.com',
                  prefixIcon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.15, end: 0),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: 'Minimal 8 karakter',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.15, end: 0),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _confirmController,
                  label: 'Konfirmasi Password',
                  hint: 'Ulangi password',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscureConfirm,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.15, end: 0),
                const SizedBox(height: 28),
                PrimaryButton(
                  label: 'Daftar',
                  loading: loading,
                  onPressed: loading ? null : _handleRegister,
                ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.15, end: 0),
                const SizedBox(height: 20),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      const Text('Sudah punya akun? ', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: const Text(
                          'Masuk',
                          style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 400.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
