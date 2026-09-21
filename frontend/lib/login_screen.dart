import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/auth_provider.dart';
import 'core/api_service.dart';
import 'core/notification_service.dart';
import 'core/i18n/app_language.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  bool _isRegisterMode = false;
  bool _acceptedLegal = false;
  String? _localError;
  String? _sessionExpiredMessage;

  static final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  @override
  void initState() {
    super.initState();
    // Se muestra una sola vez: si el usuario llegó aquí porque su token
    // expiró en medio de una sesión, se lo explicamos en vez de dejarlo
    // preguntándose por qué lo sacamos.
    _sessionExpiredMessage = ApiService.sessionExpiredMessage;
    ApiService.sessionExpiredMessage = null;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthProvider auth) async {
    final t = context.read<AppLanguage>().t;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    setState(() => _localError = null);

    if (email.isEmpty || password.isEmpty) return;
    if (_isRegisterMode && (firstName.isEmpty || lastName.isEmpty)) return;
    if (!_emailRegex.hasMatch(email)) {
      setState(() => _localError = t('login.invalidEmail'));
      return;
    }
    if (_isRegisterMode && !_acceptedLegal) {
      setState(() => _localError = t('login.mustAcceptLegal'));
      return;
    }

    final success = _isRegisterMode
        ? await auth.register(email, password, firstName, lastName)
        : await auth.login(email, password);

    if (!success || !mounted) return;

    final hasBlueprint = _isRegisterMode ? false : await ApiService().checkProfile();
    if (hasBlueprint) {
      // Sin esto, el próximo arranque en frío no tiene forma local de saber
      // que este usuario ya tiene blueprint: dependería de que /profile
      // responda a tiempo, y si esa llamada falla (sin red en el momento
      // justo del arranque, por ejemplo) manda al usuario a rehacer todo
      // el brief de 50 preguntas por error.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_blueprint', true);
      await NotificationService.instance.scheduleMorningReminder();
      await NotificationService.instance.scheduleNightReminder();
    }
    if (!mounted) return;
    context.go(hasBlueprint ? '/chat' : '/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final t = context.watch<AppLanguage>().t;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [Color(0xFF131B2F), Color(0xFF070B14)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.blur_on, color: Color(0xFF00E5FF), size: 28),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                'JARVIS PLANEADOR',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.w600, letterSpacing: 1.5, fontSize: 18, color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text('(Beta)', style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isRegisterMode ? t('login.createAccount') : t('login.signIn'),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 28),
                        if (_sessionExpiredMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, color: Color(0xFFFFD700), size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(_sessionExpiredMessage!, style: GoogleFonts.inter(color: const Color(0xFFFFD700), fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (_isRegisterMode) ...[
                          Row(
                            children: [
                              Expanded(child: _buildTextField(_firstNameController, t('login.firstName'), false)),
                              const SizedBox(width: 12),
                              Expanded(child: _buildTextField(_lastNameController, t('login.lastName'), false)),
                            ],
                          ),
                          const SizedBox(height: 14),
                        ],
                        _buildTextField(_emailController, t('login.email'), false),
                        const SizedBox(height: 14),
                        _buildTextField(_passwordController, t('login.password'), true),
                        if (_isRegisterMode) ...[
                          const SizedBox(height: 14),
                          _buildLegalConsentCheckbox(t),
                        ],
                        if (_localError != null || auth.errorMessage != null) ...[
                          const SizedBox(height: 14),
                          Text(_localError ?? auth.errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                        ],
                        const SizedBox(height: 22),
                        ElevatedButton(
                          onPressed: auth.isLoading ? null : () => _submit(auth),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00E5FF),
                            foregroundColor: const Color(0xFF070B14),
                            minimumSize: const Size(double.infinity, 52),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: auth.isLoading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF070B14)))
                              : Text(
                                  _isRegisterMode ? t('login.createAccountButton') : t('login.enter'),
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                        ),
                        const SizedBox(height: 14),
                        TextButton(
                          onPressed: auth.isLoading ? null : () => setState(() => _isRegisterMode = !_isRegisterMode),
                          child: Text(
                            _isRegisterMode ? t('login.alreadyHaveAccount') : t('login.noAccount'),
                            style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t('login.copyright'),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(color: Colors.white24, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegalConsentCheckbox(String Function(String) t) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _acceptedLegal,
            onChanged: (value) => setState(() => _acceptedLegal = value ?? false),
            activeColor: const Color(0xFF00E5FF),
            checkColor: const Color(0xFF070B14),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _acceptedLegal = !_acceptedLegal),
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                children: [
                  TextSpan(text: t('login.acceptPrefix')),
                  TextSpan(
                    text: t('login.legalLinkText'),
                    style: const TextStyle(color: Color(0xFF00E5FF), decoration: TextDecoration.underline),
                    recognizer: TapGestureRecognizer()..onTap = () => context.push('/legal'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, bool obscure) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: GoogleFonts.inter(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    );
  }
}
