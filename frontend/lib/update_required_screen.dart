import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'core/app_info.dart';
import 'core/i18n/app_language.dart';
import 'package:provider/provider.dart';

/// Pantalla de bloqueo total: se muestra cuando el backend reporta que
/// esta versión instalada quedó obsoleta (ver kAppBuildNumber /
/// docs/reference/06-decisions.md). No tiene drawer, no tiene botón de
/// volver, y bloquea el botón físico/gesto de "atrás" — la única salida
/// es descargar la nueva versión.
class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key});

  Future<void> _openDownload() async {
    final uri = Uri.parse(kApkDownloadUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<AppLanguage>().t;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF070B14),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.system_update_alt, color: Color(0xFF00E5FF), size: 64),
                  const SizedBox(height: 24),
                  Text(
                    t('update.title'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    t('update.body'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 15, height: 1.5),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _openDownload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: const Color(0xFF070B14),
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(t('update.button'), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  const SizedBox(height: 16),
                  SelectableText(
                    kApkDownloadUrl,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
