# 03 — Frontend

Ubicación: `frontend/lib/`

```
lib/
  main.dart                        — bootstrap: carga sesión, chequea versión, decide ruta inicial, arranca notificaciones
  language_screen.dart             — selector de idioma (ES/EN), se muestra una sola vez en el primer arranque
  update_required_screen.dart      — pantalla de bloqueo total cuando la versión instalada quedó obsoleta
  login_screen.dart                — login + registro + checkbox de consentimiento legal
  onboarding_screen.dart           — las 50 preguntas del brief + revisión final
  chat_screen.dart                 — pantalla principal: plan del día en 3 bloques
  blueprint_screen.dart            — "Mi Plan Maestro" (Life Blueprint) + botón de re-brief (con confirmación + contraseña)
  history_screen.dart              — historial + racha + predicción de energía
  account_screen.dart              — perfil, avatar, contraseña, notificaciones, idioma, eliminar cuenta
  legal_screen.dart                — Política de Privacidad y Términos de Uso
  core/
    api_service.dart               — TODAS las llamadas HTTP al backend + estado de sesión (estático)
    notification_service.dart      — notificaciones locales (3x/día)
    onboarding_questions.dart      — el banco fijo de 50 preguntas, en español e inglés
    app_info.dart                  — kAppBuildNumber (para el chequeo de versión) y el link de descarga del APK
    i18n/
      app_language.dart            — provider del idioma elegido (ES/EN), persistido, con el helper t()/tr()
      strings_es.dart, strings_en.dart — mapas planos clave→texto, uno por idioma
  providers/
    auth_provider.dart             — wrapper de ApiService con isLoading/errorMessage para la UI
    onboarding_provider.dart       — estado del brief (mensajes, revisión, respaldo offline)
    chat_provider.dart             — estado del plan diario
  routes/
    app_router.dart                — todas las rutas (go_router)
  widgets/
    jarvis_drawer.dart             — menú lateral, compartido por chat/blueprint/history/account
```

## Idioma (`core/i18n/`)

La app es bilingüe (español/inglés). El usuario elige una sola vez, en el primer arranque (`LanguageScreen`, antes que cualquier otra pantalla, incluso antes de login), y esa elección se persiste en SharedPreferences (clave `app_language`) — es una preferencia del **dispositivo**, no de la cuenta, así que no vive en el backend ni viaja entre dispositivos.

- `AppLanguage` (`ChangeNotifier`) expone `code` (`'es'`\|`'en'`), `isSelected`, y dos helpers: `t(key)` (lookup simple) y `tr(key, {params})` (igual, pero reemplaza marcadores `{nombre}` en el texto — para frases con variables como conteos o nombres, sin concatenar piezas traducidas por separado, ya que el orden de las palabras cambia entre idiomas).
- Los textos viven en dos mapas planos `Map<String, String>` (`strings_es.dart`/`strings_en.dart`), con claves tipo `'pantalla.elemento'`. Si una clave falta en el idioma actual, `t()` cae al español antes que mostrar algo vacío; si falta en los dos, devuelve la clave misma (para que un texto faltante sea visible/reportable, nunca invisible).
- **No usa el paquete `intl`/`flutter_localizations` ni `flutter gen-l10n`** — es un mapa hecho a mano, sin dependencias nuevas ni build step, consistente con la filosofía de simplicidad del resto del proyecto (banco de preguntas fijo en vez de IA dinámica, SQLite sin ORM, etc.).
- `AppLanguage` se construye una vez en `main()` y se inyecta directo (no por `context`) en `ChatProvider(appLanguage)` y `OnboardingProvider(appLanguage)`, porque esos providers necesitan textos localizados fuera del árbol de widgets (ej. `jarvisMessage`). Las pantallas (widgets) sí lo leen normalmente con `context.watch<AppLanguage>()`.
- `NotificationService` es un singleton fuera del árbol de providers: `AppLanguage.load()`/`setLanguage()` le empujan el código de idioma a `NotificationService.instance.languageCode` para que los recordatorios que agende salgan en el idioma correcto, sin que `NotificationService` necesite leer `context`.
- El idioma también se manda como `language` en las llamadas que generan contenido con IA (`/assessment`, `/daily-plan`, `/midday`) — ver [02-backend.md](02-backend.md) — así lo que genera el modelo (saludo, tareas, mensajes) también sale en el idioma elegido, no solo la interfaz estática.
- `onboarding_questions.dart` tiene **dos** bancos completos de 50 preguntas (mismo orden, mismo tipo/opciones por índice en los dos idiomas) — `getOnboardingQuestions(languageCode)` devuelve el que corresponda. Esto mantiene comparable el progreso guardado (posición + respuesta) sin importar el idioma.
- El idioma se puede cambiar después desde `/account` (sección "Idioma"), no solo en el primer arranque.

## Gestión de estado

`provider` package, patrón `ChangeNotifier`. Cuatro providers viven en el `MultiProvider` raíz de `main.dart`: `AppLanguage`, `AuthProvider`, `OnboardingProvider`, `ChatProvider` — estos dos últimos reciben `AppLanguage` por constructor (`OnboardingProvider(appLanguage)`, `ChatProvider(appLanguage)`), no por `context`, porque generan texto localizado fuera del árbol de widgets. `AppLanguage` se construye con `ChangeNotifierProvider.value` (ya existe una sola instancia, creada y cargada en `main()` antes de `runApp`) — los demás son *lazy* (Flutter Provider): no se construyen hasta que algo los lee.

`ApiService` **no** es un provider — es una clase con estado **estático** (`_token`, `_firstName`, `_lastName`, `_avatar`, `sessionExpiredMessage`) más métodos de instancia para las llamadas HTTP. Cualquier parte de la UI puede leer `ApiService.isLoggedIn`, `ApiService.avatar`, etc. directamente sin pasar por un provider (así lo usa `jarvis_drawer.dart`, por ejemplo).

## Navegación (`routes/app_router.dart`, `go_router`)

| Ruta | Pantalla | Notas |
|---|---|---|
| `/language` | `LanguageScreen` | selector de idioma, solo en el primer arranque |
| `/update-required` | `UpdateRequiredScreen` | pantalla de bloqueo total si la versión instalada quedó obsoleta — sin drawer, sin botón atrás (`PopScope(canPop: false)`) |
| `/login` | `LoginScreen` | punto de entrada si no hay sesión |
| `/onboarding` | `OnboardingScreen` | brief de 50 preguntas |
| `/chat` | `ChatScreen` | pantalla principal |
| `/blueprint` | `BlueprintScreen` | |
| `/history` | `HistoryScreen` | |
| `/account` | `AccountScreen` | |
| `/legal` | `LegalScreen` | se llega con `context.push` (no `.go`) desde login/cuenta, así el botón atrás regresa a donde estabas |

`main.dart` decide la ruta inicial en este orden de prioridad: **1)** versión obsoleta (`GET /version`, comparado contra `kAppBuildNumber`) → `/update-required`, bloquea todo lo demás; si esa llamada falla (sin red), nunca bloquea por eso, solo por una versión de verdad vieja. **2)** idioma no elegido todavía (`AppLanguage.isSelected == false`) → `/language`. **3)** sin sesión → `/login`; con sesión pero sin blueprint → `/onboarding`; con sesión y blueprint → `/chat`. El chequeo de blueprint usa primero el flag local `has_blueprint` en SharedPreferences y solo golpea `/profile` si ese flag no está (por ejemplo, reinstalación de la app).

## `core/api_service.dart`

Único punto de contacto con el backend. Cosas importantes:

- **Sesión**: `_token`, `_firstName`, `_lastName`, `_avatar` son estáticos y se cargan de SharedPreferences en `loadStoredToken()` (llamado una vez al arrancar `main()`). `logout()` limpia todo.
- **401 centralizado**: `_reportIfUnauthorized(response)` se llama después de cada request. Si es 401: pone `sessionExpiredMessage`, hace `logout()`, y llama al callback `onUnauthorized` (asignado en `main.dart` a `router.go('/login')`). Así el usuario nunca queda en un estado "logueado" con un token que ya no sirve.
- **Errores amigables**: `_friendlyError(response, fallback)` intenta leer `data['error']` del backend (esos mensajes ya vienen en español, listos para mostrar) y si no puede, usa un mensaje genérico — nunca se le muestra al usuario el cuerpo crudo de una respuesta de error.
- `getOnboardingProgress()` es la excepción a "todos los GET tragan su propio error": **sí lanza** en vez de devolver `[]`, porque el llamador (`OnboardingProvider`) necesita distinguir "no hay progreso todavía" de "no pudimos saberlo" — ver el respaldo offline más abajo.
- Métodos de cuenta (`updateProfile`, `uploadAvatar`, `removeAvatar`, `changePassword`, `deleteAccount`, `verifyPassword`) actualizan el estado estático Y SharedPreferences en cuanto el backend confirma éxito. `verifyPassword` no tiene efecto secundario — solo confirma la contraseña actual, usado antes de regenerar el Life Blueprint (ver más abajo).
- `getVersionInfo()`: pública, sin auth, se consulta al arrancar para el chequeo de versión obsoleta (ver [06-decisions.md](06-decisions.md)). Si falla, devuelve `null` — nunca bloquea la app por un problema de red, solo por una versión de verdad vieja.
- `getTodayLog()`, `getLifeBlueprint()`, `getHistory()` reintentan hasta 3 veces (con una pausa corta entre intentos) ante fallas de red antes de rendirse — la primera llamada tras un arranque en frío puede fallar porque la red del dispositivo aún no está lista, y un solo fallo ahí no debe hacer perder el plan del día.
- **Caché en memoria de blueprint e historial** (`_cachedBlueprint`, `_cachedHistory`, estáticos, viven lo que dura la sesión de la app, se limpian en `logout()`): `getLifeBlueprint()`/`getHistory()` devuelven la caché si ya existe en vez de golpear la red (aceptan `forceRefresh: true` para saltarla). `submitAssessment()` puebla `_cachedBlueprint` directamente con su propia respuesta (el backend no manda `updatedAt` ahí, así que se sintetiza como "ahora" en UTC) — así la primera vez que se abre "Mi Plan Maestro" justo después de terminar el brief no espera un segundo viaje de red. `ChatProvider` además dispara `getHistory`/`getLifeBlueprint` en segundo plano (sin esperar) apenas se construye, para que History y Blueprint ya tengan datos listos cuando el usuario los abra.

## `providers/onboarding_provider.dart` — el más complejo

Estado: `messages` (lista `{role, text}` alternando jarvis/user, igual que el `onboarding_progress` del backend), `questionCount`, `reviewMode`, `currentAreaLabel/Index/QuestionNumber` (para la barra de progreso).

Puntos clave:
- **Preguntas locales**: `_fetchNextQuestion()` no llama a la IA — indexa directo en `onboardingQuestions[questionCount]` (banco fijo). Por eso el brief nunca puede fallar por red *durante* las preguntas — solo el paso final (`finalizeOnboarding()`, que sí llama a `/assessment`) depende de la IA.
- **Modo revisión**: al llegar a la pregunta 50, **no** se genera el blueprint automático — se activa `reviewMode = true` y la UI muestra las 50 respuestas para editar antes de confirmar (`updateAnswer(pairIndex, newAnswer)`).
- **Compatibilidad de progreso guardado**: `_isProgressCompatible(progress)` compara cada mensaje `jarvis` guardado contra `onboardingQuestions` posición por posición. Si no calzan (por ejemplo, progreso viejo de cuando las preguntas las generaba la IA dinámicamente), se descarta y se empieza de cero — tanto local como en el backend. Este mecanismo es genérico: si el banco de preguntas vuelve a cambiar en el futuro, el progreso viejo se auto-invalida solo, sin necesitar limpieza manual.
- **Respaldo offline**: cada cambio a `messages` se guarda también en SharedPreferences (`_saveLocalBackup`). Si `getOnboardingProgress()` del backend falla (sin red), `_initOnboarding()` usa ese respaldo local en vez de asumir que no había nada y perder un brief a medias.
- **Botón "Atrás" y "Saltar pregunta"**: `goBack()` descarta la pregunta actual + la respuesta anterior (deja la anterior lista para reescribirse). `skipQuestion()` es simplemente `submitAnswer('(el usuario prefirió no responder esta pregunta)')` — reusa toda la lógica normal.

## `providers/chat_provider.dart`

Estado: `plan` (`{greeting, morning, midday, night}`), `completed` (`Map<String, bool>`, claves `'ai-<block>-<index>'` o el id propio de una tarea manual con prefijo `'manual-'`), `manualTasks`, `dayStarted`, `showMiddayInput`.

- `_hydrateToday()`: al construirse, pide `/daily-log/<hoy>` (con reintentos, ver [06-decisions.md](06-decisions.md)) y si `actions_chosen` ya tiene un plan guardado, restaura el estado completo (así cerrar y abrir la app no reinicia el día). Si la red falla, cae a un respaldo local (`_loadLocalBackup`, mismo patrón que `OnboardingProvider`). Si ni siquiera eso tiene algo que ofrecer, respeta un límite duro antes de volver a pedir energía: máximo 2 veces al día, con al menos 8 horas entre una y otra (`_canShowEnergyPrompt`); si ya se llegó al límite, se muestra un botón de "Reintentar" (`retryHydrate()`) en vez de los botones de energía.
- Cada cambio (marcar tarea, agregar/quitar tarea manual) llama a `_persistState()`, que manda el objeto `{plan, completed, manualTasks}` completo a `/daily-actions` — **no hay merge parcial en el backend**, cada guardado sobreescribe todo — y además refresca el respaldo local de hoy.
- Al generar el plan (`requestDailyPlan`), agenda la notificación de mitad de día 6h después.
- `triggerMiddayCheck()`: si la respuesta de `/midday` trae `plan` (el backend decidió que el cambio de energía ameritaba regenerar `midday`/`night`, ver [06-decisions.md](06-decisions.md)), reemplaza `plan` y `completed` enteros con lo que vino del backend y llama a `_persistState()`. Si no trae `plan` (cambio de energía menor), solo actualiza el mensaje — las tareas del día no cambian.
- `canRequestMiddayCheck`: el botón manual "Chequeo de energía ahora" solo se muestra si pasaron al menos 6 horas desde el último reporte de energía (`_lastEnergyCheckAt`, persistido en SharedPreferences). Se actualiza tanto al generar el plan matutino como al completar un chequeo de mediodía (ver [06-decisions.md](06-decisions.md)).

## `blueprint_screen.dart` — regenerar el Life Blueprint pide confirmación + contraseña

`_confirmAndStartRebrief()` reemplazó el botón directo de "Actualizar mi Plan de Vida": ahora abre un diálogo que explica que esto reemplaza el blueprint actual y pide la contraseña, verificada con `AuthProvider.verifyPassword` (sin efecto secundario, no cambia nada) antes de arrancar `OnboardingProvider.startRebrief()`. Evita que un toque accidental descarte un blueprint existente.

También nunca muestra "no tienes un blueprint" ni un mensaje de error de red: si `getLifeBlueprint()` no trae nada (tras sus reintentos internos), la pantalla se queda en el spinner de carga en vez de un estado vacío — mismo criterio aplicado en `history_screen.dart` (nunca "todavía no hay registros", siempre el spinner de `common.loading`) por pedido explícito del usuario: prefiere una carga que nunca termina de resolver a un mensaje que declare "no hay nada".

## `core/notification_service.dart` — 3 notificaciones/día

| Notificación | Cuándo | Recurrente |
|---|---|---|
| Matutina | hora configurable (default 8:00) | sí, diaria |
| Mitad de día | 6h después de generar el plan del día | no, una vez por día que se genera |
| Nocturna | hora configurable (default 21:00) | sí, diaria |

Horas configurables desde `/account` (`getMorningTime`/`setMorningTime`, `getNightTime`/`setNightTime`, guardadas en SharedPreferences).

Los títulos/cuerpos de las 3 notificaciones (y los nombres/descripciones de sus canales de Android) están en español e inglés dentro del propio archivo, elegidos según `languageCode` (campo público en `NotificationService.instance`, no viene de `context` porque es un singleton fuera del árbol de providers — ver la sección de Idioma arriba). Los IDs de canal (`morning_check_channel`, etc.) se mantienen fijos entre idiomas; solo el nombre/descripción visible cambia.

**Todo método de agendar/cancelar traga su propio error** (`_safeSchedule`) — esto es deliberado y corrige un bug real que existió: si el agendado fallaba (ícono faltante, permisos, lo que sea), el error se propagaba y aparecía como si hubiera fallado la operación principal (ej. "no se pudo generar tu blueprint" cuando en realidad el blueprint sí se guardó, solo falló la notificación). Ver [06-decisions.md](06-decisions.md).

El ícono de notificación (`android/app/src/main/res/drawable/ic_notification.png`) debe ser una silueta blanca sobre transparente — Android tiñe los íconos de notificación automáticamente, un ícono a color se ve como un bloque sólido.

## Almacenamiento local (`SharedPreferences`, todas las claves)

| Clave | Contenido |
|---|---|
| `auth_token` | JWT |
| `user_first_name`, `user_last_name` | nombre cacheado |
| `user_avatar` | avatar cacheado (data URI completo) |
| `has_blueprint` | bool, evita golpear `/profile` en cada arranque |
| `onboarding_local_backup` | respaldo del brief en progreso |
| `notif_morning_hour`, `notif_morning_minute`, `notif_night_hour`, `notif_night_minute` | horas de notificación |
| `app_language` | `'es'`\|`'en'`, elegido una sola vez en `LanguageScreen`, editable después en `/account` |
| `chat_today_backup` | respaldo local del plan de hoy (`{date, plan, completed, manualTasks}`), usado si falla la red al restaurar el día (ver [06-decisions.md](06-decisions.md)) |
| `energy_prompt_gate` | conteo + timestamp del límite duro de la pantalla de energía (máx. 2x/día, 8h mínimo) |
| `last_energy_check_at` | timestamp del último reporte de energía, usado por `canRequestMiddayCheck` (6h mínimo) |

`logout()` en `ApiService` limpia token/nombre/avatar/`has_blueprint` pero **no** toca el respaldo del brief, las horas de notificación, ni el idioma elegido (son preferencias del dispositivo, no de la cuenta).

## Diseño visual (constantes que se repiten en todas las pantallas)

- Fondo: `RadialGradient` de `Color(0xFF131B2F)` a `Color(0xFF070B14)`.
- Acento primario: `Color(0xFF00E5FF)` (cian).
- Colores de energía: baja (1-2) `Color(0xFFFF007F)` (rosa), normal (3) `Color(0xFFFFD700)` (dorado), alta (4-5) `Color(0xFF00E5FF)` (cian) — mismo código de color en `history_screen.dart` y `chat_screen.dart`.
- Fuentes: `google_fonts` — `GoogleFonts.outfit` para títulos/números, `GoogleFonts.inter` para texto de cuerpo.
- Tarjetas: `Colors.white.withValues(alpha: 0.05)` de fondo + borde `Colors.white.withValues(alpha: 0.1)`, `borderRadius` entre 12-20.
- Efecto glassmorphic (`BackdropFilter` + `ImageFilter.blur`) en barras de input y el drawer.

## Tests

`frontend/test/widget_test.dart` — un solo smoke test que verifica que `JarvisApp` construye y navega a `/blueprint` sin tirar excepciones. No hay cobertura de widgets individuales ni de providers más allá de esto. El test hace `await tester.pump(const Duration(seconds: 3))` después de montar el árbol: en el entorno de test toda petición HTTP falla con 400, lo que dispara los reintentos con espera de `getTodayLog`/`getLifeBlueprint`/`getHistory` — sin ese pump, el binding de test se queja de timers pendientes al destruir el árbol de widgets antes de que esos reintentos terminen.
