import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'providers/auth_provider.dart';
import 'providers/onboarding_provider.dart';
import 'providers/chat_provider.dart';
import 'routes/app_router.dart';
import 'core/api_service.dart';
import 'core/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.loadStoredToken();

  final prefs = await SharedPreferences.getInstance();
  bool hasBlueprint = false;

  if (ApiService.isLoggedIn) {
    hasBlueprint = prefs.getBool('has_blueprint') ?? false;
    if (!hasBlueprint) {
      // Si no está en local, verificamos en el backend por si reinstaló la app
      hasBlueprint = await ApiService().checkProfile();
      if (hasBlueprint) {
        await prefs.setBool('has_blueprint', true);
      }
    }
  }

  final initialLocation = !ApiService.isLoggedIn
      ? '/login'
      : (hasBlueprint ? '/chat' : '/onboarding');
  final router = getAppRouter(initialLocation);

  // Si el token queda inválido/vencido en cualquier llamada, volvemos a login.
  ApiService.onUnauthorized = () => router.go('/login');

  await NotificationService.instance.init(router);
  if (ApiService.isLoggedIn && hasBlueprint) {
    await NotificationService.instance.scheduleMorningReminder();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => OnboardingProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: JarvisApp(router: router),
    ),
  );
}

class JarvisApp extends StatelessWidget {
  final RouterConfig<Object> router;
  const JarvisApp({super.key, required this.router});

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
      routerConfig: router,
    );
  }
}
