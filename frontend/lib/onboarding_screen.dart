import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'providers/onboarding_provider.dart';
import 'core/onboarding_questions.dart';
import 'core/i18n/app_language.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowIntroDialog());
  }

  void _maybeShowIntroDialog() {
    if (!mounted) return;
    final provider = context.read<OnboardingProvider>();
    final t = context.read<AppLanguage>().t;
    if (provider.questionCount != 0) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF131B2F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFF00E5FF)),
            const SizedBox(width: 10),
            Text(t('onboarding.introTitle'), style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          t('onboarding.introBody'),
          style: GoogleFonts.inter(color: Colors.white70, height: 1.5, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(t('onboarding.introConfirm'), style: GoogleFonts.inter(color: const Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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

  void _confirmReview(OnboardingProvider provider) async {
    final shouldNavigate = await provider.finalizeOnboarding();
    if (shouldNavigate && mounted) {
      context.go('/chat');
    }
  }

  Future<void> _editAnswer(OnboardingProvider provider, int index, String question, String currentAnswer) async {
    final t = context.read<AppLanguage>().t;
    final controller = TextEditingController(text: currentAnswer);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF131B2F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(t('onboarding.editAnswerTitle'), style: GoogleFonts.outfit(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(question, style: GoogleFonts.inter(color: Colors.white54, fontSize: 12, height: 1.4)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(t('common.cancel'), style: GoogleFonts.inter(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              provider.updateAnswer(index, controller.text);
              Navigator.pop(dialogContext);
            },
            child: Text(t('common.save'), style: GoogleFonts.inter(color: const Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _goBack(OnboardingProvider provider) {
    _controller.clear();
    provider.goBack();
  }

  void _skip(OnboardingProvider provider) async {
    if (provider.isLoading) return;
    _controller.clear();
    final shouldNavigate = await provider.skipQuestion();
    if (shouldNavigate && mounted) {
      context.go('/chat');
    }
  }

  Widget _buildSmallActionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white54),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildAnswerArea(OnboardingProvider provider, String Function(String) t) {
    final questions = provider.questions;
    if (provider.questionCount >= questions.length) {
      return const SizedBox.shrink();
    }

    final currentQuestion = questions[provider.questionCount];
    switch (currentQuestion.type) {
      case OnboardingQuestionType.scale:
        return _buildScaleInput(provider, currentQuestion);
      case OnboardingQuestionType.choice:
        return _buildChoiceInput(provider, currentQuestion);
      case OnboardingQuestionType.text:
        return _buildTextInput(provider, t);
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

  Widget _buildTextInput(OnboardingProvider provider, String Function(String) t) {
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
                      hintText: t('onboarding.answerHint'),
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

  Widget _buildReviewItem(OnboardingProvider provider, int index, String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question, style: GoogleFonts.inter(color: Colors.white54, fontSize: 12, height: 1.4)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(answer, style: GoogleFonts.inter(color: Colors.white, fontSize: 14, height: 1.4))),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => _editAnswer(provider, index, question, answer),
                child: const Icon(Icons.edit_outlined, color: Color(0xFF00E5FF), size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewBody(OnboardingProvider provider, String Function(String) t) {
    final pairs = provider.reviewPairs;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSmallActionButton(Icons.arrow_back_ios_new, t('onboarding.editLastQuestion'), () => _goBack(provider)),
              const SizedBox(height: 10),
              Text(
                t('onboarding.reviewTitle'),
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 4),
              Text(
                t('onboarding.reviewSubtitle'),
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            itemCount: pairs.length,
            itemBuilder: (context, index) => _buildReviewItem(provider, index, pairs[index].key, pairs[index].value),
          ),
        ),
        if (provider.errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(provider.errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: ElevatedButton(
            onPressed: provider.isLoading ? null : () => _confirmReview(provider),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: const Color(0xFF070B14),
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: provider.isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF070B14)))
                : Text(t('onboarding.confirmAndGenerate'), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ),
      ],
    );
  }

  Widget _buildChatBody(OnboardingProvider provider, String Function(String) t) {
    return Column(
            children: [
              if (provider.currentAreaLabel != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (provider.canGoBack) ...[
                            _buildSmallActionButton(Icons.arrow_back_ios_new, t('onboarding.back'), () => _goBack(provider)),
                            const SizedBox(width: 16),
                          ],
                          if (provider.questionCount < provider.maxQuestions && !provider.isLoading)
                            _buildSmallActionButton(Icons.skip_next, t('onboarding.skipQuestion'), () => _skip(provider)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            t('onboarding.areaProgress')
                                .replaceAll('{area}', '${provider.currentAreaIndex + 1}')
                                .replaceAll('{label}', provider.currentAreaLabel ?? ''),
                            style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
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

              _buildAnswerArea(provider, t),
            ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnboardingProvider>();
    final t = context.watch<AppLanguage>().t;

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
          child: provider.reviewMode ? _buildReviewBody(provider, t) : _buildChatBody(provider, t),
        ),
      ),
    );
  }
}
