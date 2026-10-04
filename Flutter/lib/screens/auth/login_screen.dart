import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/primary_button.dart';

/// Layar login. Login & lupa password sudah tersambung ke Firebase
/// Authentication asli lewat [authControllerProvider]. Login dengan
/// Google sengaja belum diaktifkan — di luar cakupan Phase 2.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    // Text color di-set eksplisit ke putih. Tanpa ini, SnackBar memakai
    // warna teks default Material 3 (onInverseSurface) yang didesain untuk
    // background TERANG bawaan SnackBar — begitu backgroundColor kita timpa
    // jadi gelap (AppColors.surfaceElevated), teksnya jadi gelap-di-atas-gelap
    // dan nyaris tidak terlihat. Ini akar masalah "taskbar tidak terlihat".
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

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showMessage('Email dan password wajib diisi.');
      return;
    }

    final controller = ref.read(authControllerProvider.notifier);
    final success = await controller.signIn(email: email, password: password);
    if (!mounted) return;
    if (!success) {
      _showMessage(controller.errorMessage ?? 'Gagal masuk. Coba lagi.');
      return;
    }
    // Berhasil: tidak perlu navigasi manual. Auth guard di appRouter
    // (core/router/app_router.dart) otomatis mengarahkan ke /home begitu
    // authStateChangesProvider melaporkan user sudah login.
  }

  Future<void> _handleForgotPassword() async {
    final emailController = TextEditingController(text: _emailController.text.trim());
    final submittedEmail = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Reset Password', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: emailController,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'nama@email.com',
            hintStyle: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(emailController.text.trim()),
            child: const Text('Kirim', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );

    if (submittedEmail == null || submittedEmail.isEmpty || !mounted) return;

    final controller = ref.read(authControllerProvider.notifier);
    final success = await controller.sendPasswordReset(submittedEmail);
    if (!mounted) return;
    _showMessage(
      success
          ? 'Link reset password telah dikirim ke $submittedEmail.'
          : controller.errorMessage ?? 'Gagal mengirim email reset.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final loading = authState.isLoading;

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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                      boxShadow: [
                        BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 24, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: const Icon(Icons.water_drop_rounded, color: Colors.white, size: 32),
                  ),
                ).animate().fadeIn(duration: 400.ms).scale(
                      begin: const Offset(0.7, 0.7),
                      end: const Offset(1, 1),
                      curve: Curves.easeOutBack,
                    ),
                const SizedBox(height: 24),
                Text(
                  'Masuk ke FloodGuard',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2, end: 0),
                const SizedBox(height: 6),
                const Text(
                  'Pantau risiko banjir di lokasi Anda secara real-time.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
                ).animate().fadeIn(delay: 150.ms),
                const SizedBox(height: 32),
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
                  hint: '••••••••',
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
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: Checkbox(
                            value: _rememberMe,
                            activeColor: AppColors.primary,
                            onChanged: (v) => setState(() => _rememberMe = v ?? false),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('Ingat saya', style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                      ],
                    ),
                    TextButton(
                      onPressed: loading ? null : _handleForgotPassword,
                      child: const Text(
                        'Lupa password?',
                        style: TextStyle(color: AppColors.primary, fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 300.ms),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'Masuk',
                  loading: loading,
                  onPressed: loading ? null : _handleLogin,
                ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.15, end: 0),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(child: Divider(color: AppColors.surfaceElevated)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('atau', style: TextStyle(color: AppColors.textSecondary.withOpacity(0.9), fontSize: 12)),
                    ),
                    const Expanded(child: Divider(color: AppColors.surfaceElevated)),
                  ],
                ).animate().fadeIn(delay: 400.ms),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () => _showMessage(
                    'Masuk dengan Google belum tersedia — di luar cakupan Phase 2.',
                  ),
                  icon: const Icon(Icons.g_mobiledata_rounded, size: 24, color: AppColors.textPrimary),
                  label: const Text('Masuk dengan Google'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    side: const BorderSide(color: AppColors.surfaceElevated),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    foregroundColor: AppColors.textPrimary,
                  ),
                ).animate().fadeIn(delay: 450.ms),
                const SizedBox(height: 28),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      const Text('Belum punya akun? ', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      GestureDetector(
                        onTap: () => context.push('/register'),
                        child: const Text(
                          'Daftar',
                          style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 500.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
