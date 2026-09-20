import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/chat_provider.dart';
import 'widgets/jarvis_drawer.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _energyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _energyController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _energyController.dispose();
    super.dispose();
  }

  void _handleSubmit(ChatProvider provider) {
    if (provider.isLoading) return;
    
    if (provider.showMiddayInput) {
      provider.triggerMiddayCheck(_energyController.text);
    } else {
      provider.requestBriefing(_energyController.text);
    }
  }

  void _handleAudio(ChatProvider provider) async {
    if (provider.isRecording) {
      final transcribedText = await provider.stopRecordingAndTranscribe();
      if (transcribedText != null) {
        _energyController.text = transcribedText;
      }
    } else {
      provider.startRecording();
    }
  }

  Widget _buildOptionCard(String goal, dynamic option, ChatProvider provider) {
    bool isSelected = provider.selectedActions[goal] == option;
    
    String intensity = option['level'] ?? option['intensity'] ?? 'Media';
    
    Color intensityColor;
    switch(intensity) {
      case 'Suave': intensityColor = const Color(0xFF00E5FF); break; // Cyan
      case 'Intensa': intensityColor = const Color(0xFFFF007F); break; // Neon Pink
      default: intensityColor = const Color(0xFFFFD700); // Gold
    }

    return GestureDetector(
      onTap: () => provider.toggleAction(goal, option),
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? intensityColor.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
                border: Border.all(
                  color: isSelected ? intensityColor.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.1),
                  width: isSelected ? 1.5 : 1
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(intensity, style: GoogleFonts.outfit(color: intensityColor, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(option['action'] ?? '', 
                    style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4), 
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 14, color: Colors.white54),
                      const SizedBox(width: 4),
                      Text(option['time_estimate'] ?? '-- min', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ).animate().scale(duration: 200.ms, curve: Curves.easeOut),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    bool canConfirm = provider.morningOptions != null && provider.selectedActions.length == provider.morningOptions!.keys.length;
    bool canShowMic = _energyController.text.trim().isEmpty;

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
            Text('JARVIS', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, letterSpacing: 4.0, color: Colors.white)),
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

              // Render Morning Options or Selected Habits
              if (provider.morningOptions != null)
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      if (provider.dayStarted)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Text("TUS HÁBITOS DE HOY", style: GoogleFonts.outfit(color: const Color(0xFFFF007F), fontWeight: FontWeight.w600, letterSpacing: 1.5)),
                        ),
                      ...provider.morningOptions!.entries.map((entry) {
                        // If day started, only show the selected action for this goal
                        if (provider.dayStarted) {
                          final selectedOption = provider.selectedActions[entry.key];
                          if (selectedOption == null) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(entry.key.toUpperCase(), style: GoogleFonts.outfit(color: const Color(0xFFFF007F), fontWeight: FontWeight.w600, letterSpacing: 1.5)),
                                ),
                                SizedBox(
                                  width: double.infinity,
                                  child: _buildOptionCard(entry.key, selectedOption, provider)
                                ),
                              ]
                            )
                          );
                        }

                        // Otherwise show all options for selection
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Text(entry.key.toUpperCase(), style: GoogleFonts.outfit(color: const Color(0xFF00E5FF), fontWeight: FontWeight.w600, letterSpacing: 1.5)),
                            ),
                            SizedBox(
                              height: 170,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: (entry.value as List).length,
                                  itemBuilder: (context, index) {
                                    return SizedBox(
                                      width: 170,
                                      child: _buildOptionCard(entry.key, entry.value[index], provider)
                                    );
                                  },
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                )
              else
                const Spacer(),

              // Confirm Button
              if (canConfirm && !provider.dayStarted)
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: ElevatedButton(
                    onPressed: provider.confirmDay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: const Color(0xFF070B14),
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 10,
                      shadowColor: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                    ),
                    child: Text('Confirmar Selección', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
                  ).animate().fadeIn().moveY(begin: 10, end: 0),
                ),

              // Midday Simulator Button
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
                    child: Text('Simular Check-in (+6 horas)', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
                  ).animate().fadeIn().moveY(begin: 10, end: 0),
                ),

              // Input Area (Glassmorphic)
              if (provider.morningOptions == null || provider.showMiddayInput)
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
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _energyController,
                              style: GoogleFonts.inter(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: provider.isRecording ? 'Escuchando...' : 'Nivel de energía (1-5)...',
                                hintStyle: TextStyle(color: provider.isRecording ? const Color(0xFFFF007F) : Colors.white.withValues(alpha: 0.3)),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.05),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              ),
                              onSubmitted: (_) => _handleSubmit(provider),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onLongPressStart: canShowMic ? (_) => provider.startRecording() : null,
                            onLongPressEnd: canShowMic ? (_) => _handleAudio(provider) : null,
                            onTap: () {
                              if (!canShowMic) _handleSubmit(provider);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: provider.isRecording ? const Color(0xFFFF007F) : const Color(0xFF00E5FF).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                                border: Border.all(color: provider.isRecording ? Colors.transparent : const Color(0xFF00E5FF).withValues(alpha: 0.5)),
                                boxShadow: provider.isRecording 
                                  ? [const BoxShadow(color: Color(0xFFFF007F), blurRadius: 20, spreadRadius: 2)]
                                  : [],
                              ),
                              child: Icon(
                                canShowMic ? Icons.mic : Icons.send, 
                                color: provider.isRecording ? Colors.white : const Color(0xFF00E5FF),
                                size: 22
                              ),
                            ).animate(
                              onPlay: (controller) => canShowMic && !provider.isRecording ? controller.repeat(reverse: true) : controller.stop(),
                            ).scale(begin: const Offset(1,1), end: const Offset(1.05, 1.05), duration: 1.seconds, curve: Curves.easeInOut),
                          ),
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
