import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/api_service.dart';
import 'widgets/jarvis_drawer.dart';

class BlueprintScreen extends StatefulWidget {
  const BlueprintScreen({super.key});

  @override
  State<BlueprintScreen> createState() => _BlueprintScreenState();
}

class _BlueprintScreenState extends State<BlueprintScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  Map<String, dynamic>? _blueprint;
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
          _blueprint = data;
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
    final goals = _blueprint!['goals'] as List<dynamic>? ?? [];
    final routine = _blueprint!['daily_routine'] ?? 'No routine specified';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionHeader('Tus Metas Principales'),
        const SizedBox(height: 15),
        ...goals.map((goal) => _buildGoalCard(goal.toString())).toList(),
        const SizedBox(height: 30),
        _buildSectionHeader('Rutina Diaria Sugerida'),
        const SizedBox(height: 15),
        _buildRoutineCard(routine.toString()),
      ].animate(interval: 100.ms).fade(duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOutQuad),
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

  Widget _buildGoalCard(String goalText) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
