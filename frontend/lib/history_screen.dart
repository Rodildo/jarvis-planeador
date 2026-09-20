import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/api_service.dart';
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

  static const _weekdays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  static const _months = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final logs = await _api.getHistory(days: 30);
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

  String _formatDate(String isoDate) {
    final date = DateTime.tryParse(isoDate);
    if (date == null) return isoDate;
    return '${_weekdays[date.weekday - 1]} ${date.day} ${_months[date.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const JarvisDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Historial', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [Color(0xFF131B2F), Color(0xFF070B14)],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
            : _logs.isEmpty
                ? Center(
                    child: Text(
                      'Todavía no hay registros.\nVuelve luego de tu primer chequeo de energía.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: Colors.white70, fontSize: 15, height: 1.5),
                    ),
                  )
                : _buildList(),
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _logs.length,
      itemBuilder: (context, index) {
        final log = _logs[index];
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
                      _formatDate(log['date']?.toString() ?? ''),
                      style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      habits > 0
                          ? '$habits hábito${habits == 1 ? '' : 's'} confirmado${habits == 1 ? '' : 's'}'
                          : 'Sin hábitos confirmados',
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
