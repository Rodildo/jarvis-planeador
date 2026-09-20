import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'providers/auth_provider.dart';
import 'core/api_service.dart';
import 'core/notification_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRegisterMode = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthProvider auth) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) return;

    final success = _isRegisterMode
        ? await auth.register(email, password)
        : await auth.login(email, password);

    if (!success || !mounted) return;

    final hasBlueprint = _isRegisterMode ? false : await ApiService().checkProfile();
    if (hasBlueprint) {
      await NotificationService.instance.scheduleMorningReminder();
    }
    if (!mounted) return;
    context.go(hasBlueprint ? '/chat' : '/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

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
                            Text('JARVIS', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, letterSpacing: 4.0, color: Colors.white)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isRegisterMode ? 'Crea tu cuenta' : 'Inicia sesión',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 28),
                        _buildTextField(_emailController, 'Correo', false),
                        const SizedBox(height: 14),
                        _buildTextField(_passwordController, 'Contraseña', true),
                        if (auth.errorMessage != null) ...[
                          const SizedBox(height: 14),
                          Text(auth.errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
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
                                  _isRegisterMode ? 'Crear cuenta' : 'Entrar',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                        ),
                        const SizedBox(height: 14),
                        TextButton(
                          onPressed: auth.isLoading ? null : () => setState(() => _isRegisterMode = !_isRegisterMode),
                          child: Text(
                            _isRegisterMode ? '¿Ya tienes cuenta? Inicia sesión' : '¿No tienes cuenta? Regístrate',
                            style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
                          ),
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
