import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/api_service.dart';
import 'providers/onboarding_provider.dart';
import 'widgets/jarvis_drawer.dart';

class _AreaInfo {
  final String label;
  final IconData icon;
  const _AreaInfo(this.label, this.icon);
}

// Debe reflejar exactamente las claves de LIFE_AREAS en backend/src/ai/gemini.ts
const Map<String, _AreaInfo> _areaInfo = {
  'salud': _AreaInfo('Salud física y mental', Icons.favorite_border),
  'carrera_finanzas': _AreaInfo('Carrera y finanzas', Icons.work_outline),
  'relaciones': _AreaInfo('Relaciones y familia', Icons.people_outline),
  'crecimiento': _AreaInfo('Crecimiento personal y hábitos', Icons.self_improvement),
  'proposito': _AreaInfo('Propósito y visión de vida', Icons.explore_outlined),
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
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBlueprint();
  }

  Future<void> _loadBlueprint() async {
    try {
      final data = await _api.getLifeBlueprint();
      if (mounted) {
        setState(() {
          _blueprint = data?['blueprint'];
          final rawUpdatedAt = data?['updatedAt'];
          _updatedAt = rawUpdatedAt != null ? DateTime.tryParse('${rawUpdatedAt}Z') : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _startRebrief() async {
    await context.read<OnboardingProvider>().startRebrief();
    if (mounted) context.go('/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const JarvisDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Mi Plan Maestro', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
          : _error != null
              ? Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)))
              : _blueprint == null
                  ? const Center(child: Text('No blueprint found'))
                  : _buildBlueprintContent(),
    );
  }

  Widget _buildBlueprintContent() {
    final lifeVision = _blueprint!['life_vision']?.toString() ?? '';
    final areas = (_blueprint!['areas'] as Map?)?.cast<String, dynamic>() ?? {};
    final routine = _blueprint!['daily_routine']?.toString() ?? 'Sin rutina especificada';

    final daysSinceUpdate = _updatedAt != null ? DateTime.now().difference(_updatedAt!).inDays : null;
    final suggestRebrief = daysSinceUpdate != null && daysSinceUpdate >= 30;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (lifeVision.isNotEmpty) ...[
          _buildVisionCard(lifeVision),
          const SizedBox(height: 30),
        ],
        for (final entry in _areaInfo.entries)
          if (areas[entry.key] != null) ...[
            _buildAreaSection(entry.value, areas[entry.key] as Map<String, dynamic>),
            const SizedBox(height: 24),
          ],
        _buildSectionHeader('Rutina Diaria Sugerida'),
        const SizedBox(height: 15),
        _buildRoutineCard(routine),
        const SizedBox(height: 30),
        if (suggestRebrief)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Han pasado $daysSinceUpdate días desde tu último brief. Vale la pena actualizarlo.',
              style: GoogleFonts.inter(color: const Color(0xFFFFD700), fontSize: 13),
            ),
          ),
        OutlinedButton.icon(
          onPressed: _startRebrief,
          icon: const Icon(Icons.refresh, color: Color(0xFF00E5FF)),
          label: Text('Actualizar mi Plan de Vida', style: GoogleFonts.inter(color: const Color(0xFF00E5FF), fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFF00E5FF)),
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ].animate(interval: 80.ms).fade(duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOutQuad),
    );
  }

  Widget _buildVisionCard(String vision) {
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
          Text('TU VISIÓN DE VIDA', style: GoogleFonts.outfit(color: const Color(0xFF00E5FF), fontWeight: FontWeight.w600, letterSpacing: 1.5, fontSize: 12)),
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

  Widget _buildAreaSection(_AreaInfo info, Map<String, dynamic> area) {
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
              child: Text(info.label, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
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
