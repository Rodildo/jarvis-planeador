import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'core/api_service.dart';
import 'core/i18n/app_language.dart';
import 'widgets/jarvis_drawer.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Un año completo: mientras más historial, más confiable el patrón por
    // día de la semana que alimenta la predicción de mañana.
    final logs = await _api.getHistory(days: 365);
    if (mounted) {
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    }
  }

  Color _energyColor(dynamic level) {
    if (level == null) return Colors.white24;
    final parsed = level is int ? level : int.tryParse(level.toString()) ?? 0;
    if (parsed <= 2) return const Color(0xFFFF007F);
    if (parsed == 3) return const Color(0xFFFFD700);
    return const Color(0xFF00E5FF);
  }

  int _habitCount(dynamic rawActions) {
    if (rawActions == null) return 0;
    try {
      final decoded = jsonDecode(rawActions as String) as Map<String, dynamic>;
      return decoded.length;
    } catch (_) {
      return 0;
    }
  }

  String _formatDate(String isoDate, AppLanguage lang) {
    final date = DateTime.tryParse(isoDate);
    if (date == null) return isoDate;
    return '${lang.weekdayAbbrev[date.weekday - 1]} ${date.day} ${lang.monthAbbrev[date.month - 1]}';
  }

  String _habitsLabel(int habits, AppLanguage lang) {
    if (habits == 0) return lang.t('history.noHabits');
    if (lang.code == 'en') return '$habits habit${habits == 1 ? '' : 's'} confirmed';
    return '$habits hábito${habits == 1 ? '' : 's'} confirmado${habits == 1 ? '' : 's'}';
  }

  String _streakLabel(int streak, AppLanguage lang) {
    if (lang.code == 'en') return 'day streak';
    return streak == 1 ? 'día seguido' : 'días seguidos';
  }

  /// Días consecutivos (contando desde hoy, o desde ayer si todavía no
  /// hizo el chequeo de hoy) con al menos un registro de energía matutina.
  int _computeStreak() {
    final dateSet = _logs
        .map((l) => DateTime.tryParse(l['date']?.toString() ?? ''))
        .whereType<DateTime>()
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet();
    if (dateSet.isEmpty) return 0;

    final today = DateTime.now();
    var cursor = DateTime(today.year, today.month, today.day);
    if (!dateSet.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }

    int streak = 0;
    while (dateSet.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  double? _weeklyAverage() {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final recentLevels = _logs.where((l) {
      final date = DateTime.tryParse(l['date']?.toString() ?? '');
      return date != null && date.isAfter(weekAgo) && l['energy_morning'] != null;
    }).map((l) => (l['energy_morning'] as num).toDouble());
    if (recentLevels.isEmpty) return null;
    return recentLevels.reduce((a, b) => a + b) / recentLevels.length;
  }

  /// Predicción de mañana basada en tu propio historial: qué tan seguido,
  /// en el mismo día de la semana, tu energía fue alta/normal/baja. Si no
  /// hay suficientes registros de ese día en particular, cae al patrón
  /// general de todos tus días registrados.
  _EnergyPrediction? _predictTomorrow() {
    final withEnergy = _logs.where((l) => l['energy_morning'] != null).toList();
    if (withEnergy.isEmpty) return null;

    final tomorrowWeekday = DateTime.now().add(const Duration(days: 1)).weekday;
    var sample = withEnergy.where((l) {
      final date = DateTime.tryParse(l['date']?.toString() ?? '');
      return date != null && date.weekday == tomorrowWeekday;
    }).toList();

    const minSampleForWeekdayPattern = 3;
    final usedWeekdayPattern = sample.length >= minSampleForWeekdayPattern;
    if (!usedWeekdayPattern) sample = withEnergy;

    int high = 0, normal = 0, low = 0;
    for (final log in sample) {
      final level = log['energy_morning'];
      final parsed = level is int ? level : int.tryParse(level.toString()) ?? 3;
      if (parsed <= 2) {
        low++;
      } else if (parsed == 3) {
        normal++;
      } else {
        high++;
      }
    }
    final total = sample.length;
    return _EnergyPrediction(
      highPct: high / total * 100,
      normalPct: normal / total * 100,
      lowPct: low / total * 100,
      sampleSize: total,
      usedWeekdayPattern: usedWeekdayPattern,
      weekday: tomorrowWeekday,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppLanguage>();
    final t = lang.t;
    return Scaffold(
      drawer: const JarvisDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(t('history.title'), style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [Color(0xFF131B2F), Color(0xFF070B14)],
          ),
        ),
        // Nunca se muestra un mensaje de "no hay registros" (pedido
        // explícito del usuario): mientras esté cargando o el historial
        // todavía esté vacío, se queda mostrando el spinner de carga.
        child: (_isLoading || _logs.isEmpty)
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
            : _buildBody(lang),
      ),
    );
  }

  Widget _buildBody(AppLanguage lang) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _logs.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) return _buildInsightsCard(lang);
        if (index == 1) return _buildPredictionCard(lang);
        final log = _logs[index - 2];
        final habits = _habitCount(log['actions_chosen']);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(log['date']?.toString() ?? '', lang),
                      style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _habitsLabel(habits, lang),
                      style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              _buildEnergyBadge('AM', log['energy_morning']),
              const SizedBox(width: 8),
              _buildEnergyBadge('PM', log['energy_midday']),
            ],
          ),
        ).animate(delay: (index * 30).ms).fadeIn(duration: 300.ms).slideX(begin: 0.05, end: 0);
      },
    );
  }

  Widget _buildInsightsCard(AppLanguage lang) {
    final t = lang.t;
    final streak = _computeStreak();
    final avg = _weeklyAverage();
    final chronological = _logs.reversed.toList(); // más viejo -> más nuevo, para el gráfico

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat(Icons.local_fire_department, '$streak', _streakLabel(streak, lang), const Color(0xFFFF007F)),
              _buildStat(Icons.bolt, avg != null ? avg.toStringAsFixed(1) : '—', t('history.weeklyAverage'), const Color(0xFF00E5FF)),
            ],
          ),
          const SizedBox(height: 22),
          Text(t('history.morningEnergyHeader'), style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11, letterSpacing: 1)),
          const SizedBox(height: 12),
          SizedBox(
            height: 60,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: chronological.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final log = chronological[index];
                final level = log['energy_morning'];
                final parsedLevel = level == null ? 0 : (level is int ? level : int.tryParse(level.toString()) ?? 0);
                final color = _energyColor(level);
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: 10,
                    height: (parsedLevel / 5 * 50).clamp(4, 50).toDouble(),
                    decoration: BoxDecoration(
                      color: level == null ? Colors.white12 : color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionCard(AppLanguage lang) {
    final t = lang.t;
    final prediction = _predictTomorrow();
    if (prediction == null) return const SizedBox.shrink();

    final weekdayName = lang.weekdayFull[prediction.weekday - 1];
    final weekdayPlural = lang.code == 'en'
        ? '${weekdayName}s'
        : weekdayName; // en español el nombre del día ya no cambia en plural coloquial ("los lunes")

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_graph, color: Color(0xFF00E5FF), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lang.tr('history.predictionTitle', {'weekday': weekdayName}),
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            prediction.usedWeekdayPattern
                ? lang.tr('history.predictionBasedOn', {'count': '${prediction.sampleSize}', 'weekday': weekdayPlural})
                : lang.tr('history.predictionFallback', {'weekday': weekdayPlural}),
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 11, height: 1.4),
          ),
          const SizedBox(height: 16),
          _buildPredictionBar(t('history.levelHigh'), prediction.highPct, const Color(0xFF00E5FF)),
          const SizedBox(height: 8),
          _buildPredictionBar(t('history.levelNormal'), prediction.normalPct, const Color(0xFFFFD700)),
          const SizedBox(height: 8),
          _buildPredictionBar(t('history.levelLow'), prediction.lowPct, const Color(0xFFFF007F)),
          if (prediction.sampleSize < 5) ...[
            const SizedBox(height: 14),
            Text(
              t('history.lowConfidence'),
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 11, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPredictionBar(String label, double pct, Color color) {
    return Row(
      children: [
        SizedBox(width: 56, child: Text(label, style: GoogleFonts.inter(color: Colors.white70, fontSize: 12))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 42,
          child: Text(
            '${pct.round()}%',
            textAlign: TextAlign.right,
            style: GoogleFonts.outfit(color: color, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildStat(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(value, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
        Text(label, style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  Widget _buildEnergyBadge(String label, dynamic level) {
    final color = _energyColor(level);
    return Column(
      children: [
        Text(label, style: GoogleFonts.inter(color: Colors.white38, fontSize: 10)),
        const SizedBox(height: 4),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: level == null ? 0.05 : 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: level == null ? 0.2 : 0.6)),
          ),
          alignment: Alignment.center,
          child: Text(
            level?.toString() ?? '-',
            style: GoogleFonts.outfit(color: color, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _EnergyPrediction {
  final double highPct;
  final double normalPct;
  final double lowPct;
  final int sampleSize;
  final bool usedWeekdayPattern;
  final int weekday; // 1=lunes .. 7=domingo

  const _EnergyPrediction({
    required this.highPct,
    required this.normalPct,
    required this.lowPct,
    required this.sampleSize,
    required this.usedWeekdayPattern,
    required this.weekday,
  });
}
