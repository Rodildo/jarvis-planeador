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
import 'core/app_info.dart';
import 'core/i18n/app_language.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.loadStoredToken();

  final appLanguage = AppLanguage();
  await appLanguage.load();

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

  // Chequeo de versión: si el backend dice que esta build ya quedó
  // obsoleta, se bloquea todo lo demás. Si la llamada falla (sin red),
  // nunca se bloquea por eso — solo por una versión de verdad vieja.
  bool forceUpdate = false;
  try {
    final versionInfo = await ApiService().getVersionInfo();
    final minBuild = versionInfo?['minBuildNumber'];
    if (minBuild is int && kAppBuildNumber < minBuild) forceUpdate = true;
  } catch (e) {
    debugPrint('Version check failed, continuing: $e');
  }

  final initialLocation = forceUpdate
      ? '/update-required'
      : !appLanguage.isSelected
          ? '/language'
          : !ApiService.isLoggedIn
              ? '/login'
              : (hasBlueprint ? '/chat' : '/onboarding');
  final router = getAppRouter(initialLocation);

  // Si el token queda inválido/vencido en cualquier llamada, volvemos a login.
  ApiService.onUnauthorized = () => router.go('/login');

  // Las notificaciones son una funcionalidad secundaria: si fallan por lo
  // que sea (ícono faltante, permisos, zona horaria en un dispositivo
  // específico), la app debe seguir arrancando igual, nunca quedarse en
  // pantalla en blanco por esto.
  try {
    await NotificationService.instance.init(router);
    if (ApiService.isLoggedIn && hasBlueprint) {
      await NotificationService.instance.scheduleMorningReminder();
      await NotificationService.instance.scheduleNightReminder();
    }
  } catch (e) {
    debugPrint('Notification init failed, continuing without it: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appLanguage),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => OnboardingProvider(appLanguage)),
        ChangeNotifierProvider(create: (_) => ChatProvider(appLanguage)),
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
      title: 'Jarvis Planeador',
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
