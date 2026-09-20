import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'providers/onboarding_provider.dart';
import 'core/onboarding_questions.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(OnboardingProvider provider) {
    final text = _controller.text;
    _controller.clear();
    _submitDirect(provider, text);
  }

  void _submitDirect(OnboardingProvider provider, String answer) async {
    if (provider.isLoading) return;
    final shouldNavigate = await provider.submitAnswer(answer);
    if (shouldNavigate && mounted) {
      context.go('/chat');
    }
  }

  void _retryFinalize(OnboardingProvider provider) async {
    final shouldNavigate = await provider.finalizeOnboarding();
    if (shouldNavigate && mounted) {
      context.go('/chat');
    }
  }

  void _goBack(OnboardingProvider provider) {
    _controller.clear();
    provider.goBack();
  }

  Widget _buildAnswerArea(OnboardingProvider provider) {
    final waitingToFinalize = provider.questionCount >= provider.maxQuestions;

    // Ya se respondieron las 50 preguntas pero falló la generación del
    // blueprint (único paso que depende de la IA): se ofrece reintentar en
    // vez de perder las respuestas.
    if (waitingToFinalize && provider.errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: ElevatedButton(
          onPressed: provider.isLoading ? null : () => _retryFinalize(provider),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00E5FF),
            foregroundColor: const Color(0xFF070B14),
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text('Reintentar', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
        ),
      );
    }

    // Generando el blueprint (o esperando la primera pregunta): no hay
    // nada que responder todavía.
    if (waitingToFinalize || provider.questionCount >= onboardingQuestions.length) {
      return const SizedBox.shrink();
    }

    final currentQuestion = onboardingQuestions[provider.questionCount];
    switch (currentQuestion.type) {
      case OnboardingQuestionType.scale:
        return _buildScaleInput(provider, currentQuestion);
      case OnboardingQuestionType.choice:
        return _buildChoiceInput(provider, currentQuestion);
      case OnboardingQuestionType.text:
        return _buildTextInput(provider);
    }
  }

  Widget _buildScaleInput(OnboardingProvider provider, OnboardingQuestion q) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (q.scaleLowLabel != null || q.scaleHighLabel != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(q.scaleLowLabel ?? '', style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
                  Text(q.scaleHighLabel ?? '', style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (int level = 1; level <= 5; level++)
                GestureDetector(
                  onTap: () => _submitDirect(provider, level.toString()),
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
                      '$level',
                      style: GoogleFonts.outfit(color: const Color(0xFF00E5FF), fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceInput(OnboardingProvider provider, OnboardingQuestion q) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final option in q.options ?? const <String>[])
            GestureDetector(
              onTap: () => _submitDirect(provider, option),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.4)),
                ),
                child: Text(option, style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextInput(OnboardingProvider provider) {
    // Bottom Input Area (Glassmorphic)
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: GoogleFonts.inter(color: Colors.white),
                  decoration: InputDecoration(
                      hintText: 'Escribe tu respuesta...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                  onSubmitted: (_) {
                    if (!provider.isLoading) _submit(provider);
                  },
                ),
              ),
              const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    if (!provider.isLoading) {
                      _submit(provider);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.5)),
                    ),
                    child: const Icon(
                      Icons.send,
                      color: Color(0xFF00E5FF),
                      size: 22
                    )
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnboardingProvider>();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Building Blueprint', style: GoogleFonts.outfit(fontWeight: FontWeight.w300, fontSize: 16, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [Color(0xFF131B2F), Color(0xFF070B14)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              if (provider.currentAreaLabel != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              if (provider.canGoBack)
                                GestureDetector(
                                  onTap: () => _goBack(provider),
                                  child: const Padding(
                                    padding: EdgeInsets.only(right: 8),
                                    child: Icon(Icons.arrow_back_ios_new, size: 14, color: Colors.white54),
                                  ),
                                ),
                              Text(
                                'Área ${provider.currentAreaIndex + 1}/5 · ${provider.currentAreaLabel}',
                                style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
                          Text(
                            '${provider.questionCount}/${provider.maxQuestions}',
                            style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: provider.questionCount / provider.maxQuestions,
                          minHeight: 4,
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          color: const Color(0xFF00E5FF),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: provider.messages.length,
                  itemBuilder: (context, index) {
                    final isUser = provider.messages[index]['role'] == 'user';
                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              decoration: BoxDecoration(
                                color: isUser ? const Color(0xFF00E5FF).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
                                border: Border.all(color: isUser ? const Color(0xFF00E5FF).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.1)),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                provider.messages[index]['text']!, 
                                style: GoogleFonts.inter(
                                  color: isUser ? const Color(0xFF00E5FF) : Colors.white, 
                                  fontSize: 15, 
                                  height: 1.5
                                )
                              ),
                            ),
                          ),
                        ),
                      ).animate().fadeIn(duration: 500.ms, curve: Curves.easeOutQuad).slideY(begin: 0.2, end: 0),
                    );
                  },
                ),
              ),
              
              if (provider.isLoading)
                const Padding(
                  padding: EdgeInsets.all(20.0), 
                  child: CircularProgressIndicator(color: Color(0xFF00E5FF), strokeWidth: 2)
                ).animate().fadeIn(),
              
              if (provider.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(provider.errorMessage!, style: const TextStyle(color: Colors.redAccent)),
                ),

              _buildAnswerArea(provider),
            ],
          ),
        ),
      ),
    );
  }
}
