import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'providers/onboarding_provider.dart';
import 'providers/chat_provider.dart';
import 'routes/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final bool hasBlueprint = prefs.getBool('has_blueprint') ?? false;
  final initialLocation = hasBlueprint ? '/chat' : '/onboarding';

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => OnboardingProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: JarvisApp(initialLocation: initialLocation),
    ),
  );
}

class JarvisApp extends StatelessWidget {
  final String initialLocation;
  const JarvisApp({super.key, required this.initialLocation});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Jarvis',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00E5FF),
          brightness: Brightness.dark,
          surface: Colors.transparent,
        ),
        scaffoldBackgroundColor: const Color(0xFF070B14),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme).apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
      ),
      routerConfig: getAppRouter(initialLocation),
    );
  }
}
