import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'providers/onboarding_provider.dart';

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

  void _submit(OnboardingProvider provider) async {
    final text = _controller.text;
    _controller.clear();
    final shouldNavigate = await provider.submitAnswer(text);
    if (shouldNavigate && mounted) {
      context.go('/chat');
    }
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

              // Bottom Input Area (Glassmorphic)
              ClipRRect(
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
