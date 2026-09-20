import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/chat_provider.dart';
import 'widgets/jarvis_drawer.dart';

class _BlockSpec {
  final String key;
  final String label;
  final Color color;
  const _BlockSpec(this.key, this.label, this.color);
}

const List<_BlockSpec> _blocks = [
  _BlockSpec('morning', 'AL LEVANTARTE', Color(0xFF00E5FF)),
  _BlockSpec('midday', 'DURANTE EL DÍA', Color(0xFFFFD700)),
  _BlockSpec('night', 'AL FINAL DEL DÍA', Color(0xFFFF007F)),
];

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  void _selectEnergy(int level, ChatProvider provider) {
    if (provider.isLoading) return;

    if (provider.showMiddayInput) {
      provider.triggerMiddayCheck(level.toString());
    } else {
      provider.requestDailyPlan(level.toString());
    }
  }

  Widget _buildEnergyButton(int level, ChatProvider provider) {
    return GestureDetector(
      onTap: () => _selectEnergy(level, provider),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.5)),
        ),
        alignment: Alignment.center,
        child: Text(
          level.toString(),
          style: GoogleFonts.outfit(color: const Color(0xFF00E5FF), fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
    );
  }

  Future<void> _showAddTaskDialog(BuildContext context, String block, ChatProvider provider) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF131B2F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Agregar tarea', style: GoogleFonts.outfit(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Escribe tu tarea...',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
          ),
          onSubmitted: (value) {
            provider.addManualTask(block, value);
            Navigator.pop(dialogContext);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancelar', style: GoogleFonts.inter(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              provider.addManualTask(block, controller.text);
              Navigator.pop(dialogContext);
            },
            child: Text('Agregar', style: GoogleFonts.inter(color: const Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskTile({
    required String id,
    required String text,
    String? reason,
    required Color color,
    required ChatProvider provider,
    bool isManual = false,
  }) {
    final done = provider.completed[id] ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: done ? color.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: done ? color.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        onTap: () => provider.toggleTaskDone(id),
        leading: Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, color: done ? color : Colors.white38),
        title: Text(
          text,
          style: GoogleFonts.inter(
            color: done ? Colors.white38 : Colors.white,
            decoration: done ? TextDecoration.lineThrough : null,
            fontSize: 14,
          ),
        ),
        subtitle: (reason != null && reason.isNotEmpty)
            ? Text(reason, style: GoogleFonts.inter(color: Colors.white38, fontSize: 12))
            : null,
        trailing: isManual
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                onPressed: () => provider.removeManualTask(id),
              )
            : null,
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  Widget _buildBlockSection(_BlockSpec block, ChatProvider provider) {
    final aiTasks = (provider.plan?[block.key] as List?) ?? [];
    final manualForBlock = provider.manualTasks.where((t) => t['block'] == block.key).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(block.label, style: GoogleFonts.outfit(color: block.color, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
              GestureDetector(
                onTap: () => _showAddTaskDialog(context, block.key, provider),
                child: Icon(Icons.add_circle_outline, color: block.color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < aiTasks.length; i++)
            _buildTaskTile(
              id: 'ai-${block.key}-$i',
              text: aiTasks[i]['task']?.toString() ?? '',
              reason: aiTasks[i]['reason']?.toString(),
              color: block.color,
              provider: provider,
            ),
          for (final task in manualForBlock)
            _buildTaskTile(
              id: task['id'].toString(),
              text: task['text']?.toString() ?? '',
              color: block.color,
              provider: provider,
              isManual: true,
            ),
          if (aiTasks.isEmpty && manualForBlock.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Sin tareas para este bloque todavía.', style: GoogleFonts.inter(color: Colors.white38, fontSize: 13)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();

    return Scaffold(
      extendBodyBehindAppBar: true,
      drawer: const JarvisDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.blur_on, color: Color(0xFF00E5FF), size: 28)
                .animate(onPlay: (controller) => controller.repeat(reverse: true))
                .scale(begin: const Offset(1,1), end: const Offset(1.2, 1.2), duration: 2.seconds)
                .shimmer(duration: 2500.ms, color: Colors.white),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'JARVIS PLANEADOR',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600, letterSpacing: 1.5, fontSize: 15, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Text('(Beta)', style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
          ],
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [Color(0xFF131B2F), Color(0xFF070B14)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Jarvis Message Bubble
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.05),
                        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.2)),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.assistant, color: Color(0xFF00E5FF), size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(provider.jarvisMessage,
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 15, height: 1.5)
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ).animate().slideY(begin: -0.1, end: 0, curve: Curves.easeOutBack, duration: 600.ms).fadeIn(),

              if (provider.isLoading)
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(color: Color(0xFF00E5FF), strokeWidth: 2),
                ).animate().fadeIn(),

              // Guía del día: 3 bloques (al levantarte / durante el día / al final del día)
              if (provider.plan != null)
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      for (final block in _blocks) _buildBlockSection(block, provider),
                      const SizedBox(height: 20),
                    ],
                  ),
                )
              else
                const Spacer(),

              // Chequeo de energía a mitad de día
              if (provider.dayStarted && !provider.showMiddayInput)
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: ElevatedButton(
                    onPressed: provider.showMidday,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF007F),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 10,
                      shadowColor: const Color(0xFFFF007F).withValues(alpha: 0.5),
                    ),
                    child: Text('Chequeo de energía ahora', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
                  ).animate().fadeIn().moveY(begin: 10, end: 0),
                ),

              // Input Area (Glassmorphic) - selector de energía 1 a 5
              if (provider.plan == null || provider.showMiddayInput)
                ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          for (int level = 1; level <= 5; level++) _buildEnergyButton(level, provider),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
