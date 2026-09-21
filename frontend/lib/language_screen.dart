import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/api_service.dart';
import 'core/i18n/app_language.dart';

/// Se muestra una sola vez, en el primer arranque de la app, antes que
/// cualquier otra pantalla (incluso antes de login). Bilingüe por
/// naturaleza: todavía no hay idioma elegido, así que el texto se muestra
/// en los dos a la vez en vez de usar AppLanguage.t.
class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  String _selected = 'es';

  Future<void> _confirm() async {
    await context.read<AppLanguage>().setLanguage(_selected);
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final hasBlueprint = prefs.getBool('has_blueprint') ?? false;
    final next = !ApiService.isLoggedIn ? '/login' : (hasBlueprint ? '/chat' : '/onboarding');
    if (mounted) context.go(next);
  }

  Widget _buildOption({required String code, required String flag, required String label}) {
    final selected = _selected == code;
    return GestureDetector(
      onTap: () => setState(() => _selected = code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 140,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF00E5FF).withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? const Color(0xFF00E5FF) : Colors.white.withValues(alpha: 0.15), width: selected ? 2 : 1),
        ),
        child: Column(
          children: [
            Text(flag, style: const TextStyle(fontSize: 44)),
            const SizedBox(height: 10),
            Text(label, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.blur_on, color: Color(0xFF00E5FF), size: 40),
                const SizedBox(height: 20),
                Text(
                  'Elige tu idioma\nChoose your language',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20, height: 1.4),
                ),
                const SizedBox(height: 36),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildOption(code: 'es', flag: '🇪🇸', label: 'Español'),
                    _buildOption(code: 'en', flag: '🇺🇸', label: 'English'),
                  ],
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: const Color(0xFF070B14),
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('Aceptar / Accept', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
