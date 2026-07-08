import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/network/auth_provider.dart';
import '../../shared/providers/theme_provider.dart';
import '../../shared/theme/app_colors.dart';
import 'cloud_sync_provider.dart';

/// Tampilkan modal login/register sebagai dialog di tengah layar.
Future<bool> showAuthGate(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (ctx) => const _AuthDialog(),
  );
  return result ?? false;
}

class _AuthDialog extends ConsumerStatefulWidget {
  const _AuthDialog();

  @override
  ConsumerState<_AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends ConsumerState<_AuthDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _loginFormKey    = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  final _loginEmail    = TextEditingController();
  final _loginPassword = TextEditingController();
  final _regName       = TextEditingController();
  final _regEmail      = TextEditingController();
  final _regPassword   = TextEditingController();
  final _regConfirm    = TextEditingController();

  bool _loginPassVisible = false;
  bool _regPassVisible   = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmail.dispose();
    _loginPassword.dispose();
    _regName.dispose();
    _regEmail.dispose();
    _regPassword.dispose();
    _regConfirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth         = ref.watch(authProvider);
    final appThemeMode = ref.watch(themeProvider);
    final isSystemDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final isDark       = appThemeMode == AppThemeMode.dark ||
        (appThemeMode == AppThemeMode.system && isSystemDark);

    final cardColor     = AppColors.cardColor(isDark: isDark);
    final inputColor    = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
    final labelColor    = AppColors.textSecondary(isDark: isDark);
    final hintColor     = isDark ? Colors.white24 : Colors.black26;
    final textColor     = AppColors.textPrimary(isDark: isDark);
    final subtitleColor = textColor.withValues(alpha: 0.5);
    final iconBtnColor  = isDark ? Colors.white38 : Colors.black26;
    final primary       = AppColors.primary(isDark: isDark);

    // Auto-close on login success
    ref.listen(authProvider, (_, next) {
      if (next.isLoggedIn && mounted) {
        ref.read(cloudSyncProvider.notifier).pullSync();
        Navigator.of(context).pop(true);
      }
    });

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 640),
            decoration: BoxDecoration(
              color: cardColor.withValues(alpha: 0.93),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.glassBorder(isDark: isDark),
                width: 0.8,
              ),
              boxShadow: [
                AppColors.coloredShadow(isDark: isDark, opacity: 0.4),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 32,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ──────────────────────────────────────────────
                const SizedBox(height: 28),
                _buildHeader(isDark, textColor, subtitleColor)
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: -0.15),
                const SizedBox(height: 20),

                // ── Tab Bar ──────────────────────────────────────────────
                _buildTabBar(isDark, inputColor, labelColor),
                const SizedBox(height: 4),

                // ── Error Banner ─────────────────────────────────────────
                if (auth.error != null)
                  _buildErrorBanner(auth.error!)
                      .animate(key: ValueKey(auth.error))
                      .fadeIn(),

                // ── Form ─────────────────────────────────────────────────
                Flexible(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildLoginTab(
                        auth,
                        isDark: isDark,
                        textColor: textColor,
                        labelColor: labelColor,
                        hintColor: hintColor,
                        inputColor: inputColor,
                        iconBtnColor: iconBtnColor,
                        primary: primary,
                      ),
                      _buildRegisterTab(
                        auth,
                        isDark: isDark,
                        textColor: textColor,
                        labelColor: labelColor,
                        hintColor: hintColor,
                        inputColor: inputColor,
                        iconBtnColor: iconBtnColor,
                        primary: primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(bool isDark, Color textColor, Color subtitleColor) {
    return Column(
      children: [
        Container(
          width: 68, height: 68,
          decoration: BoxDecoration(
            gradient: AppColors.gradientDiagonal(isDark: isDark),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [AppColors.coloredShadow(isDark: isDark, opacity: 0.45)],
          ),
          child: const Icon(Icons.headphones_rounded, color: Colors.white, size: 34),
        ),
        const SizedBox(height: 14),
        Text(
          'iMUplay',
          style: TextStyle(
            color: textColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Masuk untuk mengakses fitur online & sinkronisasi cloud',
            style: TextStyle(color: subtitleColor, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  // ── Tab Bar ────────────────────────────────────────────────────────────────
  Widget _buildTabBar(bool isDark, Color inputColor, Color labelColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: inputColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: AppColors.gradient(isDark: isDark),
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: labelColor,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        dividerColor: Colors.transparent,
        tabs: const [Tab(text: 'Masuk'), Tab(text: 'Daftar')],
      ),
    );
  }

  // ── Error Banner ───────────────────────────────────────────────────────────
  Widget _buildErrorBanner(String message) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade100.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade400),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: Colors.red.shade800, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ── Login Tab ──────────────────────────────────────────────────────────────
  Widget _buildLoginTab(
    AuthState auth, {
    required bool isDark,
    required Color textColor,
    required Color labelColor,
    required Color hintColor,
    required Color inputColor,
    required Color iconBtnColor,
    required Color primary,
  }) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _loginFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInputField(
              controller: _loginEmail,
              label: 'Email',
              hint: 'Masukkan Email Anda Disini',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              textColor: textColor, labelColor: labelColor, hintColor: hintColor,
              inputColor: inputColor, iconBtnColor: iconBtnColor, primary: primary,
              validator: (v) => (v == null || !v.contains('@')) ? 'Email tidak valid' : null,
            ),
            const SizedBox(height: 14),
            _buildInputField(
              controller: _loginPassword,
              label: 'Password',
              hint: '••••••••',
              icon: Icons.lock_outline,
              obscureText: !_loginPassVisible,
              textColor: textColor, labelColor: labelColor, hintColor: hintColor,
              inputColor: inputColor, iconBtnColor: iconBtnColor, primary: primary,
              suffixIcon: IconButton(
                icon: Icon(
                  _loginPassVisible ? Icons.visibility_off : Icons.visibility,
                  color: iconBtnColor, size: 20,
                ),
                onPressed: () => setState(() => _loginPassVisible = !_loginPassVisible),
              ),
              validator: (v) => (v == null || v.length < 8) ? 'Minimal 8 karakter' : null,
            ),
            const SizedBox(height: 28),
            _buildGradientButton(
              isDark: isDark,
              label: auth.isLoading ? 'Memproses...' : 'Masuk',
              isLoading: auth.isLoading,
              onPressed: _onLogin,
            ),
          ],
        ),
      ),
    );
  }

  // ── Register Tab ───────────────────────────────────────────────────────────
  Widget _buildRegisterTab(
    AuthState auth, {
    required bool isDark,
    required Color textColor,
    required Color labelColor,
    required Color hintColor,
    required Color inputColor,
    required Color iconBtnColor,
    required Color primary,
  }) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _registerFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInputField(
              controller: _regName,
              label: 'Nama',
              hint: 'Nama lengkap Anda',
              icon: Icons.person_outline,
              textColor: textColor, labelColor: labelColor, hintColor: hintColor,
              inputColor: inputColor, iconBtnColor: iconBtnColor, primary: primary,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
            ),
            const SizedBox(height: 14),
            _buildInputField(
              controller: _regEmail,
              label: 'Email',
              hint: 'masukkan email anda disini',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              textColor: textColor, labelColor: labelColor, hintColor: hintColor,
              inputColor: inputColor, iconBtnColor: iconBtnColor, primary: primary,
              validator: (v) => (v == null || !v.contains('@')) ? 'Email tidak valid' : null,
            ),
            const SizedBox(height: 14),
            _buildInputField(
              controller: _regPassword,
              label: 'Password',
              hint: 'Minimal 8 karakter',
              icon: Icons.lock_outline,
              obscureText: !_regPassVisible,
              textColor: textColor, labelColor: labelColor, hintColor: hintColor,
              inputColor: inputColor, iconBtnColor: iconBtnColor, primary: primary,
              suffixIcon: IconButton(
                icon: Icon(
                  _regPassVisible ? Icons.visibility_off : Icons.visibility,
                  color: iconBtnColor, size: 20,
                ),
                onPressed: () => setState(() => _regPassVisible = !_regPassVisible),
              ),
              validator: (v) => (v == null || v.length < 8) ? 'Minimal 8 karakter' : null,
            ),
            const SizedBox(height: 14),
            _buildInputField(
              controller: _regConfirm,
              label: 'Konfirmasi Password',
              hint: 'Ulangi password',
              icon: Icons.lock_person_outlined,
              obscureText: !_regPassVisible,
              textColor: textColor, labelColor: labelColor, hintColor: hintColor,
              inputColor: inputColor, iconBtnColor: iconBtnColor, primary: primary,
              validator: (v) => v != _regPassword.text ? 'Password tidak sama' : null,
            ),
            const SizedBox(height: 28),
            _buildGradientButton(
              isDark: isDark,
              label: auth.isLoading ? 'Mendaftar...' : 'Buat Akun',
              isLoading: auth.isLoading,
              onPressed: _onRegister,
            ),
          ],
        ),
      ),
    );
  }

  // ── Input Field ────────────────────────────────────────────────────────────
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color textColor,
    required Color labelColor,
    required Color hintColor,
    required Color inputColor,
    required Color iconBtnColor,
    required Color primary,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: labelColor, fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: TextStyle(color: textColor),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: hintColor),
            prefixIcon: Icon(icon, color: primary, size: 20),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: inputColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade400, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
            ),
            errorStyle: TextStyle(color: Colors.red.shade700, fontSize: 11),
          ),
        ),
      ],
    );
  }

  // ── Gradient Button ────────────────────────────────────────────────────────
  Widget _buildGradientButton({
    required bool isDark,
    required String label,
    required bool isLoading,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        decoration: BoxDecoration(
          gradient: isLoading
              ? LinearGradient(colors: [Colors.grey.shade400, Colors.grey.shade400])
              : AppColors.gradient(isDark: isDark),
          borderRadius: BorderRadius.circular(14),
          boxShadow: isLoading
              ? []
              : [AppColors.coloredShadow(isDark: isDark, opacity: 0.4)],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(Colors.white70),
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────
  Future<void> _onLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;
    await ref.read(authProvider.notifier).login(
      email: _loginEmail.text.trim(),
      password: _loginPassword.text,
    );
  }

  Future<void> _onRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;
    await ref.read(authProvider.notifier).register(
      name: _regName.text.trim(),
      email: _regEmail.text.trim(),
      password: _regPassword.text,
      passwordConfirmation: _regConfirm.text,
    );
  }
}
