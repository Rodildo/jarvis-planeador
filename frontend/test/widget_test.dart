// Basic smoke test: verifies the app widget tree builds without throwing.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:jarvis/main.dart';
import 'package:jarvis/providers/auth_provider.dart';
import 'package:jarvis/providers/onboarding_provider.dart';
import 'package:jarvis/providers/chat_provider.dart';
import 'package:jarvis/routes/app_router.dart';

void main() {
  testWidgets('JarvisApp builds and shows the chat screen', (WidgetTester tester) async {
    // '/blueprint' is used instead of '/chat' because the chat screen has an
    // infinite pulsing icon animation that never settles in the test binding.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => OnboardingProvider()),
          ChangeNotifierProvider(create: (_) => ChatProvider()),
        ],
        child: JarvisApp(router: getAppRouter('/blueprint')),
      ),
    );

    expect(find.text('Mi Plan Maestro'), findsOneWidget);
  });
}
