import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/api_service.dart';
import 'core/i18n/app_language.dart';
import 'providers/auth_provider.dart';
import 'providers/onboarding_provider.dart';
import 'widgets/jarvis_drawer.dart';

class _AreaInfo {
  final String labelKey;
  final IconData icon;
  const _AreaInfo(this.labelKey, this.icon);
}

// Debe reflejar exactamente las claves de LIFE_AREAS en backend/src/ai/gemini.ts
const Map<String, _AreaInfo> _areaInfo = {
  'salud': _AreaInfo('blueprint.area.salud', Icons.favorite_border),
  'carrera_finanzas': _AreaInfo('blueprint.area.carrera_finanzas', Icons.work_outline),
  'relaciones': _AreaInfo('blueprint.area.relaciones', Icons.people_outline),
  'crecimiento': _AreaInfo('blueprint.area.crecimiento', Icons.self_improvement),
  'proposito': _AreaInfo('blueprint.area.proposito', Icons.explore_outlined),
};

class BlueprintScreen extends StatefulWidget {
  const BlueprintScreen({super.key});

  @override
  State<BlueprintScreen> createState() => _BlueprintScreenState();
}

class _BlueprintScreenState extends State<BlueprintScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  Map<String, dynamic>? _blueprint;
  DateTime? _updatedAt;
  Timer? _retryTimer;
  bool _isFetching = false;

  @override
  void initState() {
    super.initState();
    _loadBlueprint();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  void _applyBlueprint(Map<String, dynamic> data) {
    _blueprint = data['blueprint'];
    final rawUpdatedAt = data['updatedAt'];
    _updatedAt = rawUpdatedAt != null ? DateTime.tryParse('${rawUpdatedAt}Z') : null;
    _isLoading = false;
  }

  // El plan maestro solo cambia cuando el usuario termina un re-brief (ver
  // ApiService.submitAssessment, que es quien reemplaza la copia en
  // disco) — nunca por el solo hecho de abrir esta pantalla. Por eso se
  // muestra directo la copia guardada en disco (SharedPreferences), sin
  // tocar la red: con el backend a veces inestable, esperar un viaje de
  // red de por sí ya no es confiable, y esperarlo para mostrar algo que
  // de todas formas no iba a cambiar no tiene sentido.
  //
  // Solo si NUNCA hubo nada guardado (primera vez del usuario en este
  // dispositivo) hace falta ir a la red — ahí sí, con reintento cada 3
  // segundos (ver docs/reference/06-decisions.md) porque no queda otra.
  Future<void> _loadBlueprint() async {
    final cached = await _api.getCachedBlueprintFromDisk();
    if (cached != null && mounted) {
      setState(() => _applyBlueprint(cached));
      return;
    }
    await _fetchFromNetwork();
  }

  Future<void> _fetchFromNetwork() async {
    if (_isFetching) return;
    _isFetching = true;
    try {
      final data = await _api.getLifeBlueprint();
      if (!mounted) return;
      if (data?['blueprint'] != null) {
        _retryTimer?.cancel();
        setState(() => _applyBlueprint(data!));
        return;
      }
      _retryTimer ??= Timer.periodic(const Duration(seconds: 3), (_) => _fetchFromNetwork());
    } finally {
      _isFetching = false;
    }
  }

  Future<void> _confirmAndStartRebrief() async {
    final t = context.read<AppLanguage>().t;
    final passwordController = TextEditingController();
    String? localError;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF131B2F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(t('blueprint.confirmTitle'), style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t('blueprint.confirmBody'), style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, height: 1.4)),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: t('blueprint.confirmPasswordHint'),
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2))),
                ),
              ),
              if (localError != null) ...[
                const SizedBox(height: 10),
                Text(localError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(t('common.cancel'), style: GoogleFonts.inter(color: Colors.white54)),
            ),
            Consumer<AuthProvider>(
              builder: (context, auth, _) => TextButton(
                onPressed: auth.isLoading
                    ? null
                    : () async {
                        final ok = await auth.verifyPassword(passwordController.text);
                        if (ok) {
                          if (dialogContext.mounted) Navigator.pop(dialogContext);
                          await context.read<OnboardingProvider>().startRebrief();
                          if (mounted) context.go('/onboarding');
                        } else {
                          setDialogState(() => localError = auth.errorMessage);
                        }
                      },
                child: Text(t('blueprint.confirmContinue'), style: GoogleFonts.inter(color: const Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<AppLanguage>().t;
    return Scaffold(
      drawer: const JarvisDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(t('blueprint.title'), style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: (_isLoading || _blueprint == null)
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF00E5FF)),
                  const SizedBox(height: 16),
                  Text(t('common.loading'), style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
                ],
              ),
            )
          : _buildBlueprintContent(t),
    );
  }

  Widget _buildBlueprintContent(String Function(String) t) {
    final lifeVision = _blueprint!['life_vision']?.toString() ?? '';
    final areas = (_blueprint!['areas'] as Map?)?.cast<String, dynamic>() ?? {};
    final routine = _blueprint!['daily_routine']?.toString() ?? t('blueprint.noRoutine');

    final daysSinceUpdate = _updatedAt != null ? DateTime.now().difference(_updatedAt!).inDays : null;
    final suggestRebrief = daysSinceUpdate != null && daysSinceUpdate >= 30;
    final lang = context.watch<AppLanguage>();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (lifeVision.isNotEmpty) ...[
          _buildVisionCard(lifeVision, t),
          const SizedBox(height: 30),
        ],
        for (final entry in _areaInfo.entries)
          if (areas[entry.key] != null) ...[
            _buildAreaSection(entry.value, areas[entry.key] as Map<String, dynamic>, t),
            const SizedBox(height: 24),
          ],
        _buildSectionHeader(t('blueprint.dailyRoutineHeader')),
        const SizedBox(height: 15),
        _buildRoutineCard(routine),
        const SizedBox(height: 30),
        if (suggestRebrief)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              lang.tr('blueprint.rebriefSuggestion', {'days': '$daysSinceUpdate'}),
              style: GoogleFonts.inter(color: const Color(0xFFFFD700), fontSize: 13),
            ),
          ),
        OutlinedButton.icon(
          onPressed: _confirmAndStartRebrief,
          icon: const Icon(Icons.refresh, color: Color(0xFF00E5FF)),
          label: Text(t('blueprint.updateButton'), style: GoogleFonts.inter(color: const Color(0xFF00E5FF), fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFF00E5FF)),
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ].animate(interval: 80.ms).fade(duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOutQuad),
    );
  }

  Widget _buildVisionCard(String vision, String Function(String) t) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF00E5FF).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('blueprint.visionLabel'), style: GoogleFonts.outfit(color: const Color(0xFF00E5FF), fontWeight: FontWeight.w600, letterSpacing: 1.5, fontSize: 12)),
          const SizedBox(height: 10),
          Text(vision, style: GoogleFonts.inter(fontSize: 16, height: 1.5, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF00E5FF),
      ),
    );
  }

  Widget _buildAreaSection(_AreaInfo info, Map<String, dynamic> area, String Function(String) t) {
    final summary = area['summary']?.toString();
    final goals = (area['goals'] as List?)?.cast<dynamic>() ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(info.icon, color: const Color(0xFF00E5FF), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(t(info.labelKey), style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
        if (summary != null && summary.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(summary, style: GoogleFonts.inter(fontSize: 13, height: 1.4, color: Colors.white54)),
        ],
        const SizedBox(height: 12),
        ...goals.map((goal) => _buildGoalCard(goal.toString())),
      ],
    );
  }

  Widget _buildGoalCard(String goalText) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.stars, color: Color(0xFFFFD700), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              goalText,
              style: GoogleFonts.inter(fontSize: 15, height: 1.4, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutineCard(String routineText) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      padding: const EdgeInsets.all(16),
      child: Text(
        routineText,
        style: GoogleFonts.inter(fontSize: 15, height: 1.5, color: Colors.white70),
      ),
    );
  }
}
