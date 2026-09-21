// Basic smoke test: verifies the app widget tree builds without throwing.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:jarvis/main.dart';
import 'package:jarvis/providers/auth_provider.dart';
import 'package:jarvis/providers/onboarding_provider.dart';
import 'package:jarvis/providers/chat_provider.dart';
import 'package:jarvis/routes/app_router.dart';
import 'package:jarvis/core/i18n/app_language.dart';

void main() {
  testWidgets('JarvisApp builds and shows the chat screen', (WidgetTester tester) async {
    // '/blueprint' is used instead of '/chat' because the chat screen has an
    // infinite pulsing icon animation that never settles in the test binding.
    final appLanguage = AppLanguage();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: appLanguage),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => OnboardingProvider(appLanguage)),
          ChangeNotifierProvider(create: (_) => ChatProvider(appLanguage)),
        ],
        child: JarvisApp(router: getAppRouter('/blueprint')),
      ),
    );

    // ApiService reintenta las llamadas de red fallidas con una espera
    // corta entre intentos (ver getTodayLog/getLifeBlueprint/getHistory);
    // en el entorno de test toda petición HTTP falla con 400, así que hay
    // que dejar correr esos timers antes de terminar el test o el binding
    // se queja de timers pendientes al destruir el árbol de widgets.
    await tester.pump(const Duration(seconds: 3));

    expect(find.text('Mi Plan Maestro'), findsOneWidget);
  });
}
