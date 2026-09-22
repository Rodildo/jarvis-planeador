# 06 — Decisiones y su porqué

Esto existe para que nadie "arregle" algo que en realidad fue una elección deliberada. Orden cronológico aproximado.

## La app nació de un solo usuario bipolar y se generalizó

Diseño original: motor de planificación "especializado en bipolaridad" (ver `docs/superpowers/specs/`), con preguntas del brief que mencionaban "tu bipolaridad" directamente y un prompt de IA que decía "el usuario es bipolar" como hecho universal.

Cuando se agregó multiusuario, el propio usuario señaló que iba a haber gente sin esa condición usando la app. Se generalizó en dos frentes:
- Las 3 preguntas del brief que nombraban "bipolaridad" se reescribieron para ser abiertas ("¿hay alguna condición o patrón de fondo que influya?") — quien sí tenga una condición la puede mencionar con sus propias palabras; quien no, simplemente no aplica.
- El prompt de `generateDailyPlan` ahora dice explícitamente "nunca asumas ni menciones un diagnóstico específico".

**El sistema de 3 modos de energía (Refugio / Ritmo Estable / Expansión) se mantuvo** — sigue siendo útil para cualquier persona cuya energía varíe día a día, sea cual sea la causa.

## Se eliminaron las funciones de voz/audio

El diseño original (`docs/superpowers/`) planeaba interacción "estilo WhatsApp" (grabar audio, mandarlo, Gemini transcribe y responde). Se abandonó: el código de grabación (`record` package) nunca se conectó a nada funcional, tenía un bug real (`_audioRecorder.dispose()` sobre un campo que no existía, crasheaba el onboarding), y el endpoint `/transcribe` en el backend tampoco se usaba desde ningún lado. Se removió todo (paquete, permiso `RECORD_AUDIO`, endpoint, stub de transcripción) en vez de dejarlo a medias.

## OpenRouter en vez de Gemini directo

El modelo de IA pasó por varios cambios (ver `procesos_historial.txt` para el detalle de cada intento) hasta asentarse en OpenRouter con `deepseek/deepseek-v3.2`. El archivo sigue llamándose `backend/src/ai/gemini.ts` por inercia histórica — no usa la API de Google Gemini.

## Auth: JWT + bcrypt, sin sesiones

Se eligió JWT (90 días de vida) sobre sesiones con store porque el backend no tenía (ni necesitaba) infraestructura de sesiones — es un Express simple sin Redis ni nada parecido. bcrypt con 10 rounds para contraseñas, estándar razonable sin necesitar justificación adicional.

**Se decidió "arrancar en limpio"** al agregar auth: los datos viejos de `default_user` (de cuando la app era mono-usuario sin login) no se migraron a ninguna cuenta nueva. Fue una decisión explícita del usuario, no un descuido.

## Anti-abuso: nivel básico, no verificación de correo real

Al agregar registro público, se le presentaron al usuario dos niveles de protección contra registros falsos: (a) validación de formato + rate limiting por IP, sin dependencias externas: (b) lo mismo más verificación real de correo (enviar un email de confirmación), que requiere contratar/configurar un proveedor de correo transaccional. **El usuario eligió (a).** Si en el futuro se quiere subir a (b), ya se documentó como pendiente explícito (ver [07-known-gaps.md](07-known-gaps.md)) — no es que se haya olvidado, es que se pospuso a propósito.

Un efecto colateral de esto: **no hay recuperación de contraseña por email**, porque no hay servicio de correo configurado. Es el hueco más importante señalado en el pre-lanzamiento.

## Avatar: base64 en la base de datos, no archivos

Al agregar foto de perfil, la alternativa era subir archivos (multer + almacenamiento en disco + servir estático). Se eligió guardar la imagen como data URI en la columna `users.avatar` porque:
- El despliegue actual es un solo archivo SQLite en un volumen Docker — no hay infraestructura de almacenamiento de archivos ya montada.
- Evita tener que servir contenido estático nuevo o preocuparse de que la ruta del volumen coincida.
- El borrado de cuenta ya limpia todo automáticamente (es una fila más de `users`, no archivos huérfanos que limpiar aparte).

Trade-off aceptado conscientemente: no escala bien a miles de usuarios con fotos grandes. Para el tamaño actual del proyecto es la opción correcta. El cliente comprime a 512×512/calidad 70 antes de subir, y el backend rechaza (413) cualquier cosa por encima de ~750KB en base64.

## El brief pasó de "IA genera cada pregunta" a "banco fijo de 50"

Versión original: cada una de las 50 preguntas se generaba en vivo con una llamada a la IA (`/onboarding/question`), usando el historial de respuestas como contexto. Esto fallaba intermitentemente (~cada 2-3 preguntas, un error transitorio de red/OpenRouter tumbaba el flujo) — y peor, el manejo de errores guardaba el mensaje de error **como si fuera una pregunta real de Jarvis**, corrompiendo el historial que después se le mandaba a la IA para generar el blueprint.

Se reemplazó por un banco fijo de 50 preguntas escritas a mano (`onboarding_questions.dart`), con tipos mixtos (texto/escala/opción múltiple) para que no se sintiera como un formulario. Esto eliminó 49 de las 50 llamadas a IA del proceso de onboarding — solo queda una llamada real (`/assessment`, al final, para generar el blueprint). El endpoint `/onboarding/question` se eliminó del backend por completo.

**Efecto secundario deliberado**: como las preguntas ahora son deterministas, se pudo construir `_isProgressCompatible()` — compara el progreso guardado contra el banco actual pregunta por pregunta, y descarta automáticamente cualquier progreso que no calce (ya sea de la época de IA dinámica, o de un futuro cambio al banco de preguntas). Esto es autocurativo: si el banco de preguntas vuelve a cambiar, no hace falta limpieza manual de datos viejos.

## El plan diario pasó de "elige tu intensidad" a "Jarvis te guía"

Versión original: cada mañana la IA proponía 2+ metas del blueprint con 3 opciones de intensidad cada una (Suave/Media/Intensa), y el usuario elegía una por meta. El usuario pidió explícitamente cambiar esto: que la app "te diga lo que tienes que hacer" en vez de dejarte elegir, organizado en 3 momentos del día (al levantarte / durante el día / al final del día) — un modelo de guía directa en vez de un selector. De ahí sale la estructura actual de `generateDailyPlan` (`morning`/`midday`/`night`), y por extensión las 3 notificaciones diarias que corresponden a esos mismos 3 momentos.

## Predicción de energía: estadística simple, no IA

Al pedir una "predicción de probabilidad de amanecer con energía alta o baja", se descartó deliberadamente usar la IA para esto. En vez de eso, `history_screen.dart` calcula una frecuencia histórica real: de todos los días registrados que caen en el mismo día de la semana que "mañana", qué porcentaje fueron alta/normal/baja energía (con fallback al patrón general si hay menos de 3 muestras de ese día específico). Es honesto sobre lo que es — un patrón explicable de tu propio historial, no un modelo predictivo ni un diagnóstico — y no cuesta una llamada a OpenRouter cada vez que se abre el historial.

## Notificaciones: nunca pueden tumbar la app

Se descubrió (mientras se diagnosticaba un crash de pantalla blanca en el APK compilado, que resultó ser un ícono de notificación mal referenciado) que 3 puntos distintos del código llamaban a `NotificationService` sin capturar sus errores, y una falla ahí se disfrazaba de fallas en features completamente distintas (ej. "no se pudo generar tu blueprint" cuando el blueprint sí se había guardado bien, solo falló agendar el recordatorio). Se blindó de raíz: todo método de agendar/cancelar en `NotificationService` traga su propio error internamente (`_safeSchedule`) — las notificaciones son una funcionalidad secundaria y nunca deben poder bloquear un flujo principal.

## `trust proxy` — encontrado por una pregunta del usuario, no por una auditoría

Al agregar rate limiting, el usuario preguntó si 15/hora no era muy poco. Esa pregunta llevó a descubrir que `req.ip` en Express probablemente veía la IP del proxy de Traefik (EasyPanel) en vez de la del cliente real, porque nunca se configuró `trust proxy`. Efecto: el límite por IP se compartía entre **todos** los usuarios de la app, no por persona. Se corrigió (`app.set('trust proxy', 1)`) y, una vez corregido, el límite subió de 15 a 30/hora por usuario real (15 era conservador pensando en un balde compartido; 30 por persona real sigue frenando un bug en bucle sin apretar el uso normal).

Nota de proceso: en el camino se pensó (incorrectamente, corregido en la misma conversación) que esto causaba errores 500 en producción. Al revisar el código fuente de `express-rate-limit`, se confirmó que la librería atrapa ese error de validación internamente y solo lo loguea — no rompe la petición. El problema real era más sutil (el balde compartido) pero igual de importante de corregir.

## Legal: checkbox de consentimiento + aviso médico

Al agregar Política de Privacidad y Términos, se decidió exigir un checkbox explícito de aceptación en el registro (no solo dejar el link disponible) porque el brief puede tocar temas de salud mental — dado ese contexto, pedir consentimiento explícito pareció lo correcto en vez de opcional. Los Términos incluyen un aviso médico explícito: la app no sustituye atención profesional de salud mental, y en crisis se debe contactar a un profesional o servicios de emergencia. Aclaración importante que se le hizo al usuario en su momento: escribir esta política no equivale a una certificación legal — para publicación real (especialmente con usuarios en la UE, por GDPR y su categoría especial de datos de salud) se recomienda revisión de un abogado.

## Ícono/logo: fondo cuadrado + capa adaptativa separada

El logo que dio el usuario (233×246px, fondo azul marino + "J" blanca con sombra diagonal) no era cuadrado. Se rellenó a cuadrado con el mismo azul del fondo (no se estiró, para no distorsionar la letra). Para el ícono adaptativo de Android (`mipmap-anydpi-v26`) se generó una capa aparte con solo la "J" blanca sobre transparente (extraída por umbral de blancura, no por diferencia con el azul de fondo — así no arrastra la sombra diagonal como ruido), y el color de fondo se separó a `colors.xml`. El ícono de notificación usa esa misma capa transparente, redimensionada — un ícono a color ahí se vería como un bloque sólido, porque Android tiñe los íconos de notificación automáticamente a blanco/monocromático.

## "No se pudo generar tu plan del día" — timeout de proxy vs. JSON truncado

Un usuario reportó que, tras dejar la app inactiva ~1 hora, al pedir el plan del día se quedaba con ese mensaje genérico. La primera hipótesis (sin ver logs todavía) fue un timeout del proxy (Traefik/EasyPanel) devolviendo una página de error no-JSON tras un arranque en frío — se mejoró `_friendlyError` en el frontend para al menos mostrar el código HTTP real en ese caso (mejora válida igual, se mantiene).

Pero al ver los logs reales del backend, la causa era otra: `extractJson` fallaba con `SyntaxError: Unexpected end of JSON input` porque el `content` que devolvía OpenRouter venía **cortado a mitad de un string JSON** (el plan traía varias tareas verbosas y nunca se le pasó un `max_tokens` explícito a la petición, así que usaba el default del modelo). Esto no era un problema de red/proxy: la llamada a OpenRouter "tuvo éxito" con status 200, solo que el texto no alcanzó a completarse. Por eso `callOpenRouter`'s propio retry (pensado para fallos de red/HTTP) nunca se activaba — la respuesta técnicamente no había fallado.

Lección: cuando un reporte de usuario no cuadra del todo con la primera hipótesis, vale la pena pedir los logs reales del servicio en vez de asumir — la causa real (`max_tokens` faltante) era una categoría de bug completamente distinta a la que se había arreglado primero.

**Efecto secundario descubierto después**: cada falla de generación dejaba un rastro incómodo. `/daily-plan` guarda `energy_morning` (vía `saveMorningLog`) **antes** de intentar generar el plan; si la generación fallaba, `energy_morning` quedaba guardado pero `actions_chosen` (el plan en sí) nunca se llegaba a persistir. `ChatProvider._hydrateToday()` solo miraba `actions_chosen` para decidir si ya había un plan hoy, así que cada vez que el usuario reabría la app volvía a pedirle la energía desde cero — aunque ya la había reportado, quedaba "perdida" desde la perspectiva de la UI. Se corrigió haciendo que `_hydrateToday()` también revise `energy_morning`: si existe pero no hay `actions_chosen`, reintenta la generación sola con esa misma energía en vez de volver a preguntar.

## El chequeo de mediodía pasó de "solo un mensaje" a regenerar el plan cuando la energía cambia de balde

Hasta este punto, `/midday` solo devolvía un mensaje motivacional de texto (`generateMidDayAdjustment`) — el plan del día (`midday`/`night`) se quedaba fijo pase lo que pase con la energía reportada a mitad de día. El usuario preguntó cada cuánto se actualizaban las tareas y, al explicarle este comportamiento, pidió explícitamente que si la energía cae mucho a mitad de día, las tareas restantes se simplifiquen en vez de solo recibir un mensaje — consistente con la idea original de la app (adaptarse a los altibajos de energía, no solo reconocerlos).

Se implementó reutilizando los mismos 3 baldes de energía que ya usaba `generateDailyPlan` (Refugio ≤2 / Estable =3 / Expansión ≥4), factorizados a un helper compartido `energyMode`/`energyModeChanged` en `gemini.ts`. La regla: si el balde de la energía matutina y el de la energía de mediodía son **distintos** (no solo "bajó un poco"), el plan original ya no encaja de verdad, y `POST /midday` llama a una función nueva (`generateMidDayReplan`) que regenera `midday`/`night` completos (mismo formato `{task, reason}` que `generateDailyPlan`) junto con el mensaje adaptativo, en una sola llamada a la IA. Si el balde no cambió (ej. energía se mantiene "estable" aunque el número exacto varíe), se sigue usando el `generateMidDayAdjustment` original — no vale la pena una regeneración completa por un cambio menor.

Decisiones de diseño dentro de esto:
- **`morning` nunca se toca** — ya pasó, regenerarlo no tendría sentido.
- **Las tareas manuales del usuario (`manualTasks`) se conservan intactas** — son suyas, no de la IA, no hay razón para borrarlas porque cambió la energía.
- **Los `completed` de `ai-midday-*`/`ai-night-*` se descartan** al regenerar esos bloques (las tareas en esos índices ya no son las mismas, así que su estado de "completada" viejo ya no significa nada); `ai-morning-*` y los `manual-*` se conservan tal cual.
- El backend es la fuente de verdad: devuelve `{message, plan, completed}` ya combinados y los persiste él mismo en `daily_logs.actions_chosen`, así el cliente solo tiene que reemplazar su estado local con lo que vino en la respuesta en vez de recalcular nada.

## La pantalla de "¿cómo está tu energía?" reaparecía en cada apertura de la app

Un usuario reportó que, tras cerrar la app y dejarla cerrada solo unos minutos, al reabrirla volvía a aparecer la pantalla inicial pidiendo energía — pese a que ya existía un plan generado para ese día. Esto no era el mismo bug ya corregido antes (`energy_morning` guardado sin `actions_chosen`, ver arriba): esta vez el plan sí estaba completo y guardado en el backend, el problema era que `ChatProvider._hydrateToday()` no lograba **leerlo** de vuelta a tiempo.

Causa: `_hydrateToday()` es lo primero que corre al reconstruirse `ChatProvider` (un arranque en frío, típico cuando Android mata el proceso tras un rato en segundo plano), y `ApiService.getTodayLog()` es la primera llamada de red del todo — justo el momento en el que el stack de red del dispositivo puede no estar listo aún. Un solo fallo ahí (capturado y silenciado, `getTodayLog()` solo hacía `print` y devolvía `null`) bastaba para que `_hydrateToday()` asumiera que no había nada guardado y volviera a mostrar la pantalla de energía desde cero — con el riesgo real de que, si el usuario la respondía, se generara un plan nuevo de la IA que **pisara** el del día (perdiendo tareas completadas y tareas manuales) además de gastar una llamada de más.

Se corrigió con tres capas, de más simple a más defensiva:
1. **Reintentos en `getTodayLog()`**: hasta 3 intentos con 800ms de espera entre cada uno, para sobrevivir el hueco típico de "red no lista todavía" justo tras un arranque en frío.
2. **Respaldo local del plan de hoy** (`ChatProvider._saveLocalBackup()`/`_loadLocalBackup()`, clave `chat_today_backup` en SharedPreferences): cada `_persistState()` guarda también una copia local de `{date, plan, completed, manualTasks}`. Si los reintentos de red igual fallan, `_hydrateToday()` usa ese respaldo en vez de asumir que no hay nada — mismo patrón ya usado en `OnboardingProvider._saveLocalBackup()` para el progreso del brief. Un respaldo de un día distinto al de hoy se ignora (así un día nuevo de verdad sigue pidiendo energía).
3. **Límite duro explícito, pedido por el usuario**: incluso con las dos capas anteriores, si algún día ni la red ni el respaldo local tienen nada que ofrecer, `_hydrateToday()` no vuelve a mostrar la pantalla de energía sin más — respeta un tope de **máximo 2 veces al día, con al menos 8 horas de diferencia entre una y otra** (`_canShowEnergyPrompt`/`_recordEnergyPromptShown`, clave `energy_prompt_gate`). Si ya se llegó al límite, se muestra un mensaje de "no pude confirmar tu plan" con un botón de Reintentar (`ChatProvider.retryHydrate()`) en vez de los botones de energía — así ni por error se puede disparar una generación de plan de más mientras el límite sigue activo. Un día nuevo (fecha distinta a la guardada) siempre reinicia el conteo sin importar la hora.

## El botón manual de "Chequeo de energía ahora" pasó de estar siempre visible a respetar 6 horas mínimo

Antes, una vez generado el plan del día, el botón rosado de "Chequeo de energía ahora" quedaba disponible todo el tiempo — el usuario podía disparar un chequeo de mediodía (y su posible regeneración de tareas vía IA) en cualquier momento, sin relación con el intervalo de 6 horas que ya usa la notificación automática (`NotificationService.scheduleMiddayCheck(Duration(hours: 6))`). El usuario pidió explícitamente que el botón respete ese mismo mínimo de 6 horas en vez de estar siempre disponible.

Se agregó `ChatProvider.canRequestMiddayCheck`, calculado contra un timestamp `_lastEnergyCheckAt` (persistido en SharedPreferences, clave `last_energy_check_at`) que se actualiza cada vez que se reporta energía — tanto al generar el plan matutino (`_generatePlan`) como al completar un chequeo de mediodía (`triggerMiddayCheck`). El botón (`chat_screen.dart`) ahora exige `dayStarted && !showMiddayInput && canRequestMiddayCheck`; si no han pasado las 6 horas, simplemente no aparece (el chequeo automático por notificación sigue funcionando igual, ya que por diseño se dispara justo a las 6 horas). Sin timer periódico: como el resto de la app, se recalcula solo en la siguiente reconstrucción de la UI, no en tiempo real segundo a segundo — consistente con la ausencia de polling en el resto del código.

De paso se pidió que, al elegir un nivel de energía (1-5), quede claro que la app está cargando: los botones de energía ahora se atenúan y se deshabilitan mientras `isLoading` es true, y el mensaje de Jarvis pasa a decir explícitamente "Cargando tu plan del día, por favor espera..." / "Cargando tu chequeo de energía, por favor espera..." en vez del texto más genérico anterior.

## Tanda grande: botón de agregar tarea, confirmación con contraseña, "nunca pantallas vacías", versión obsoleta, y soporte bilingüe

El usuario pidió, en un mismo mensaje, cinco cosas independientes. Se hicieron todas en la misma sesión — quedan documentadas juntas porque se tocaron los mismos archivos centrales (`main.dart`, `app_router.dart`, casi todas las pantallas).

**1. Botón de "agregar tarea" más visible.** Era un ícono `+` suelto de 20px sin fondo, fácil de pasar por alto. Se convirtió en una píldora con ícono + texto "Agregar" y fondo tintado del color del bloque (`chat_screen.dart`, `_buildBlockSection`).

**2. Confirmar con contraseña antes de regenerar el Life Blueprint.** `blueprint_screen.dart` ya no llama a `startRebrief()` directo desde el botón — abre un diálogo (mismo patrón visual que "Eliminar cuenta" en `account_screen.dart`) que explica que esto reemplaza el blueprint actual y exige la contraseña. Se necesitaba un endpoint que verificara la contraseña **sin** efecto secundario (a diferencia de `/auth/change-password` o `/account`, que sí cambian/borran algo): se agregó `POST /auth/verify-password` (protegido además por `loginLimiter`, para no abrir una superficie de fuerza bruta nueva) y su wrapper `AuthProvider.verifyPassword`.

**3. "Nunca pantallas vacías."** El usuario fue explícito: prefiere ver un spinner de carga indefinidamente antes que un mensaje declarando que algo "no existe" o "está vacío" — ni "no tienes un blueprint todavía", ni "no hay registros, vuelve después de tu primer chequeo". Se aplicó en `blueprint_screen.dart` y `history_screen.dart`: mientras no haya datos que mostrar (sea por estar cargando, por una falla de red tras los reintentos, o por estar genuinamente vacío), la pantalla muestra el mismo spinner + `common.loading` en vez de cualquier mensaje de estado. Es una decisión de UX consciente, no un descuido — un spinner que nunca resuelve es normalmente peor práctica que un estado vacío claro, pero aquí es exactamente lo que se pidió, y las llamadas ya reintentan solas (ver la entrada de arriba sobre `getTodayLog`), así que en la práctica casi siempre termina resolviendo.

**4. Versión obsoleta forzada.** `GET /version` ahora devuelve también `minBuildNumber` (constante `MIN_SUPPORTED_BUILD_NUMBER` en `routes.ts`, se sube a mano cuando se quiere forzar una actualización). El cliente tiene su propio `kAppBuildNumber` (`frontend/lib/core/app_info.dart`, debe subirse a mano junto con el "+N" de `pubspec.yaml` en cada release) y lo compara al arrancar, antes de decidir cualquier otra ruta: si es menor, va a `/update-required` (`UpdateRequiredScreen`), una pantalla sin drawer y sin botón de atrás (`PopScope(canPop: false)`) con un botón que abre el link de descarga del APK (`url_launcher`, nueva dependencia). Si el chequeo de versión falla por red, **nunca** bloquea — solo bloquea ante una versión de verdad vieja, mismo criterio de "fail open" que el resto de la app.

**Limitación importante, de bootstrapping — no se puede forzar retroactivamente.** El 21 de septiembre de 2026, justo después de compilar y publicar la primera build con este mecanismo (`kAppBuildNumber = 1`, coincide con `MIN_SUPPORTED_BUILD_NUMBER = 1`), el usuario pidió forzar que todas las versiones *anteriores* a esa actualizaran. No es posible: cualquier APK instalado antes de este cambio **no tiene el código que consulta `minBuildNumber`** — no llama a `/version` con ese propósito, no sabe que el campo existe, y el backend no tiene ninguna forma de distinguir a esos clientes viejos de uno nuevo en ninguna otra petición (no mandan ningún identificador de versión). Subir `MIN_SUPPORTED_BUILD_NUMBER` no le hace nada a quien ya tiene una versión sin el chequeo instalada; solo afecta a quien ya corre una build que sí lo trae. Es la limitación inherente de estrenar este tipo de mecanismo por primera vez — no un bug, y no había forma de evitarlo. A partir de esta build (#1) en adelante, cada release nueva sí puede forzar que todos los que ya tengan #1 (o superior) actualicen, subiendo `MIN_SUPPORTED_BUILD_NUMBER` en el backend por encima del build number de esa release vieja. **Cuidado al subir ese número:** si se sube por encima del build number de la ÚLTIMA release publicada (la que la gente debería poder descargar), esa misma release queda bloqueada sin ningún build más nuevo al que mandarla — hay que subir primero el build nuevo al release de GitHub, y solo después subir `MIN_SUPPORTED_BUILD_NUMBER` a como mucho el build number de esa build recién publicada.

**5. Soporte bilingüe completo (español/inglés).** La pieza más grande. Decisiones clave:
- **Selector de idioma en el primer arranque** (`LanguageScreen`), antes que login/onboarding, con banderas y confirmación explícita. Se puede cambiar después desde `/account`.
- **Mecanismo hecho a mano, no `flutter_localizations`/`intl`/`flutter gen-l10n`**: dos mapas planos `Map<String, String>` (`strings_es.dart`/`strings_en.dart`) más una clase `AppLanguage` con `t(key)`/`tr(key, params)`. Se descartó el toolchain oficial de Flutter deliberadamente — hubiera significado una dependencia nueva (`intl`, con su propio rango de versiones atado a la SDK de Flutter), un archivo `l10n.yaml`, ARB files, y una clase generada por codegen (`flutter pub get`) — más maquinaria de la que este proyecto necesita para dos idiomas y un puñado de pantallas. Es la misma filosofía que ya rige el resto del proyecto (banco de preguntas fijo en vez de IA dinámica, SQLite sin ORM, sin build step en el backend).
- **`AppLanguage` se inyecta por constructor, no por `context`**, en `ChatProvider`/`OnboardingProvider`: esos providers generan `jarvisMessage`/mensajes de error fuera del árbol de widgets (ej. dentro de un callback async), donde no hay `BuildContext` a mano.
- **`NotificationService` es un singleton fuera del árbol de providers**: no puede leer `AppLanguage` por `context`. Se le agregó un campo público `languageCode` que `AppLanguage.load()`/`setLanguage()` mantienen sincronizado, y los textos/nombres de canal de las 3 notificaciones se arman a partir de ese campo.
- **El idioma también viaja al backend**: `/assessment`, `/daily-plan` y `/midday` aceptan `language` (`'es'`\|`'en'`, opcional) y lo pasan a las funciones de `gemini.ts`, que le agregan una instrucción final al `systemPrompt` (`languageDirective`) — así el contenido generado por la IA (saludo, tareas, mensajes) también sale en el idioma elegido, no solo el texto estático de la interfaz.
- **El banco de 50 preguntas del brief existe completo en los dos idiomas** (`onboarding_questions.dart`, `getOnboardingQuestions(languageCode)`), mismo orden y mismo tipo/opciones por índice, para que el progreso guardado siga siendo comparable posición a posición sin importar el idioma.
- **Textos de error crudos del backend no se tradujeron** (ej. "Contraseña incorrecta" de `/auth/verify-password`): son mensajes de fallback poco frecuentes, y traducirlos hubiera requerido threading de idioma en cada endpoint que devuelve errores, no solo en los 3 que generan contenido con IA. Queda como límite consciente de esta tanda de trabajo, no un olvido.

## "Nunca pantallas vacías" necesitaba también "nunca pantallas pegadas"

Efecto secundario descubierto después de la tanda anterior: `blueprint_screen.dart`/`history_screen.dart` dejaron de mostrar mensajes de error/vacío, pero solo reintentaban lo que ya reintenta `getLifeBlueprint()`/`getHistory()` por su cuenta (3 intentos con 800ms de espera, ~2.4s en total) — si eso no bastaba (por ejemplo, tras dejar la app cerrada un buen rato, la conexión del dispositivo tarda más en "despertar" de lo que cubren esos 2.4s), la pantalla se quedaba con el spinner para siempre, sin ningún reintento más. El usuario lo reportó como "se queda cargando" al abrir esas pestañas después de un rato sin usar la app.

Se agregó una capa de reintento adicional, más lenta y persistente, en las dos pantallas: si tras un intento todavía no hay datos, se arma un `Timer.periodic(Duration(seconds: 3))` que vuelve a intentar cada 3 segundos hasta que aparezcan datos, momento en el que se cancela. Dos cuidados explícitos para que esto no se convierta en un bucle descontrolado (pedido explícito del usuario):
- **Un solo intento en vuelo a la vez** (`_isFetching`): si un intento tarda más de 3 segundos, el siguiente tick del timer se ignora en vez de lanzar una llamada superpuesta.
- **El timer se cancela en dos lugares**: apenas llegan datos reales, y en `dispose()` — así cerrar la pantalla (navegar a otra pestaña) para el reintento de inmediato, nunca sigue corriendo de fondo.

Es un patrón de dos capas a propósito: la capa rápida (`api_service.dart`, unos pocos segundos) cubre baches cortos de red; la capa lenta y persistente (el `Timer.periodic` en la pantalla) cubre el caso de una desconexión más larga, sin bloquear la UI con reintentos agresivos.

## La causa real de "se queda colgada": ninguna llamada de red tenía timeout

El arreglo anterior (reintento cada 3 segundos) ayudó pero no resolvió el problema de fondo: el usuario siguió reportando que "Mi Plan Maestro" se quedaba colgada o muy lenta para cargar al reabrir la app después de un rato. Revisando `api_service.dart` a fondo: **ninguna de las 19 llamadas HTTP del archivo tenía un `.timeout(...)` explícito** — sin eso, `http.get`/`post`/etc. esperan lo que tarde el sistema operativo en darse por vencido, que puede ser mucho más que unos segundos (sobre todo justo después de que el dispositivo estuvo con la red "dormida" un rato, reconectar puede tardar bastante antes de fallar o tener éxito). Esto significa que cada uno de los 3 intentos "rápidos" de `getLifeBlueprint()`/`getHistory()`/`getTodayLog()` podía por sí solo tardar muchísimo más de lo pensado — la lógica de reintentos existía, pero cada intento individual podía quedarse pegado en vez de fallar rápido y dejar que el siguiente intento (o el `Timer.periodic` de la pantalla) hiciera su trabajo.

Se agregó `.timeout(...)` a las 19 llamadas de `api_service.dart`, con tres duraciones según el tipo de endpoint:
- `_defaultTimeout` (12s): la mayoría — lectura/escritura simple contra la base de datos, debería responder casi al instante en cualquier conexión funcional.
- `_uploadTimeout` (30s): solo `uploadAvatar` — sube hasta ~750KB en base64, más margen que un endpoint de solo texto.
- `_aiTimeout` (90s): los 3 endpoints que le pegan a OpenRouter (`submitAssessment`, `getDailyPlan`, `triggerMiddayCheck`) — el backend mismo puede reintentar una generación con JSON truncado (ver `callOpenRouterAndParseJson` en `gemini.ts`), así que legítimamente pueden tardar más que un endpoint normal.

Al vencerse el timeout, se lanza una `Exception` con un mensaje genérico en español (`_timeoutError()`) en vez de dejar que se propague la `TimeoutException` cruda de Dart (que produce un texto técnico feo tipo "TimeoutException after 0:00:12.000000..."). Con esto, cada intento dentro de un reintento (`getTodayLog`, `getHistory`, `getLifeBlueprint`) ahora falla en como mucho `_defaultTimeout`, y el chequeo de versión al arrancar la app (`main.dart` → `getVersionInfo()`) también queda acotado — antes esa llamada sin timeout podía retrasar el arranque completo de la app, no solo la pantalla de Blueprint.

## El timeout no bastó: "Mi Plan Maestro"/"Historial" seguían con el mismo síntoma — investigación a fondo

Con los timeouts explícitos ya en producción, el usuario siguió reportando exactamente el mismo síntoma ("se queda cargando en un bucle infinito") al reabrir la app tras dejarla cerrada unos minutos. Pidió una investigación profunda en vez de otro parche rápido. Se revisó de nuevo todo el camino, desde `main.dart` hasta cada llamada de red, con dos preguntas: ¿el reintento por sí solo puede volverse tan lento que se sienta infinito aunque técnicamente esté acotado?, ¿hay algo generando más carga de red de la necesaria justo en el peor momento?

**Hallazgo 1 — peticiones duplicadas en el peor momento posible.** `ChatProvider` (que se construye casi de inmediato al abrir la app, porque la ruta inicial de un usuario que ya tiene sesión y blueprint es `/chat`) dispara en su constructor, en segundo plano y sin esperar: `getHistory(days: 365)` y `getLifeBlueprint()` — para que Historial y Mi Plan Maestro ya tengan datos en caché cuando el usuario los abra. El problema: si el usuario navega a esas pantallas **mientras esa precarga todavía sigue reintentando** (muy probable justo después de un arranque en frío con la red reconectando, que es exactamente el escenario reportado), `blueprint_screen.dart`/`history_screen.dart` disparaban **su propia llamada independiente** al mismo endpoint — nada en `ApiService` compartía o coordinaba llamadas concurrentes a la misma URL. Resultado: el doble de peticiones de red compitiendo por el mismo ancho de banda escaso, justo cuando menos hay disponible.

**Hallazgo 2 — dos capas de reintento compuestas hacían cada ciclo mucho más lento de lo pensado.** `getLifeBlueprint()`/`getHistory()` reintentaban hasta 3 veces internamente (hasta `_defaultTimeout` = 12s cada intento, ~36s en el peor caso) — y por fuera, `blueprint_screen.dart`/`history_screen.dart` además esperaban otros 3 segundos antes de volver a llamar. Cada "ciclo" visible para el usuario podía tomar hasta ~40 segundos. No era técnicamente un bucle infinito (sí estaba acotado, sí eventualmente reintentaba), pero **se sentía infinito**: si la reconexión real tardaba 1-2 minutos (frecuente en algunos dispositivos/redes tras estar un rato en segundo plano), el usuario veía 2-3 "vueltas" larguísimas del spinner sin ningún indicio de progreso.

**Los tres arreglos, en `frontend/lib/core/api_service.dart` y `frontend/lib/providers/chat_provider.dart`:**
1. **De-duplicación de peticiones en curso** (`_historyInFlight`, `_blueprintInFlight`, `Future` estático): si ya hay una llamada a `getHistory()`/`getLifeBlueprint()` en curso (de la precarga o de otra pantalla), una segunda llamada simplemente espera el resultado de la primera en vez de disparar un segundo viaje de red. Elimina la duplicación de carga del Hallazgo 1 sin importar quién la pidió primero.
2. **Un solo intento por llamada, no tres**, en `getHistory()`/`getLifeBlueprint()` (renombradas internamente a `_fetchHistory`/`_fetchLifeBlueprint`, ahora sin loop): como las pantallas correspondientes ya reintentan por su cuenta cada 3 segundos, reintentar también adentro de `api_service.dart` solo alargaba cada ciclo sin aportar nada — el ciclo visible bajó de ~40s a ~15s en el peor caso (12s de timeout + 3s de espera de la pantalla). `getTodayLog()` **no** cambió: no tiene una capa de reintento externa equivalente (`ChatProvider` usa un mecanismo distinto, el límite duro de `_canShowEnergyPrompt`), así que ahí sí sigue teniendo sentido reintentar 3 veces internamente.
3. **La precarga de `ChatProvider` ahora espera a que `_hydrateToday()` resuelva** antes de disparar `getHistory`/`getLifeBlueprint`, en vez de lanzar las tres llamadas en paralelo desde el primer instante. Reduce la cantidad de conexiones simultáneas compitiendo justo en el arranque en frío, dejando que la más importante (el plan de hoy) tenga la red para ella sola primero.

Ninguno de los tres arreglos, por separado, garantizaba resolver el síntoma reportado — la combinación de los tres sí ataca las dos causas reales identificadas (duplicación de carga + reintentos compuestos demasiado lentos), no solo un reintento más frecuente por encima de un problema de fondo sin tocar.

## El backend en sí estaba cayéndose — se agregó una copia local persistente para no depender de que responda a tiempo

Con los tres arreglos anteriores ya en producción, el usuario reportó que el síntoma seguía exactamente igual. En vez de seguir ajustando el cliente, se probó el backend en producción directo con `curl`, repetidas veces en la misma ventana de tiempo:

- `GET /api/version` (público, sin auth, ni siquiera necesita tocar la base de datos) respondía **200 a veces y 404 "Cannot GET" otras veces**, en llamadas consecutivas.
- En un momento devolvió `{"version":"5.2.0-i18n","minBuildNumber":1}` — la versión de **antes** del último deploy (el código local ya tenía `5.3.0-force-update`/`minBuildNumber:2`).
- En otro momento, **todas** las rutas probadas (`/version`, `/life-areas`, `/blueprint`, `/profile`, `/onboarding/progress`, `/daily-log/:date`) devolvieron 404 "Cannot GET" a la vez, incluidas rutas públicas sin auth que llevan meses sin tocarse.

Esto confirma que el problema real es de infraestructura, no de código: el contenedor del backend está reiniciándose/cayéndose de forma intermitente en EasyPanel (posible deploy que quedó a medias o un crash-loop), sirviendo a veces código viejo y a veces nada coherente. Ningún ajuste del lado del cliente — reintentos, timeouts, de-duplicación — puede compensar un servidor que a ratos no responde nada. Se le pidió al usuario revisar el estado del deploy y los logs en EasyPanel; mientras tanto, el usuario pidió una mitigación real del lado de la app: una copia local persistente para que las pantallas nunca dependan de que el backend responda a tiempo.

**Diseño**: `api_service.dart` ya tenía una caché en memoria (`_cachedBlueprint`/`_cachedHistory`, estática, se pierde al cerrar la app) usada para de-duplicación y acceso rápido dentro de una misma sesión. Se agregó una **segunda capa, en disco** (`SharedPreferences`, sobrevive a cerrar la app), completamente separada de la de memoria, con semántica distinta según el tipo de dato:

- **Plan maestro (`getCachedBlueprintFromDisk`)**: `blueprint_screen.dart` muestra esta copia **al instante, siempre, sin tocar la red** — el plan maestro solo cambia cuando el usuario termina un re-brief (`OnboardingProvider.finalizeOnboarding` → `ApiService.submitAssessment`, el único lugar que reemplaza la copia en disco). Si nunca hubo nada guardado (primera vez en ese dispositivo), ahí sí hace falta ir a la red, con el mismo reintento cada 3 segundos ya existente como respaldo.
- **Historial (`getCachedHistoryFromDisk`)**: cambia día a día, así que no basta con mostrar la copia y quedarse ahí. `history_screen.dart` la muestra al instante (sin spinner) y de inmediato dispara una actualización en segundo plano contra la red (`getHistory(forceRefresh: true)`, que igual comparte la petición en curso si ya hay una — ver arriba); si esa actualización trae datos, reemplaza la vista en silencio. El reintento cada 3 segundos solo se activa si de verdad no hay nada que mostrar (ni disco ni red) — no tiene sentido insistir por algo que el usuario ya está viendo.
- **Se limpia en `logout()`**: es una caché de la cuenta, no del dispositivo — si otra persona inicia sesión en el mismo teléfono no debe heredar los datos de la cuenta anterior.

Con esto, aunque el backend siga inestable, el usuario ve su plan maestro y su historial de inmediato en cada apertura de la app (excepto la primerísima vez, antes de que exista cualquier copia local) — el problema de fondo (el backend cayéndose) sigue sin resolverse, pero deja de bloquear la experiencia de la app mientras se investiga y arregla del lado de EasyPanel.

## Causa real del backend inestable: contenedores Docker huérfanos peleando por la misma ruta de Traefik

Continuación de la entrada anterior. Con la caché local ya mitigando el síntoma en la app, se siguió investigando la causa de fondo — resuelta el mismo día (22 de septiembre de 2026).

**Descartado por evidencia, no por suposición:**
- **¿Cronjob o tarea programada en el código?** No. Se revisó todo `backend/src` a fondo: sin librerías de cron en `package.json`, sin ningún `setInterval` en el código. El único `setTimeout` que existe es la espera de 1.5s dentro del reintento de `callOpenRouter` (`ai/gemini.ts`), que solo corre durante una petición real, nunca en segundo plano por su cuenta.
- **¿Un bug de la aplicación (lógica, base de datos)?** No. En todas las pruebas, el backend nunca devolvió un 500 — solo `200` (bien) o `404 Cannot GET` (ruta no encontrada). Un 404 así ocurre en la capa de enrutamiento de Express, **antes** de que el código de negocio se ejecute; un bug de lógica/base de datos habría producido 500, no "ruta no encontrada".
- **¿Múltiples procesos peleando dentro del mismo contenedor?** No. `ps aux` dentro del contenedor de la app mostró un único proceso Node (PID 1), estable, sin reiniciarse.

**La causa real, encontrada con acceso a la consola del VPS (Hostinger, no solo la consola del contenedor en EasyPanel) vía `docker ps -a`:** además del contenedor legítimo (`app_jarvisplanner`, el que EasyPanel reconstruye y reinicia en cada `git push`), había **tres contenedores huérfanos** corriendo desde hacía 4 días — `jarvis-manual`, `jarvis-manual-backend`, y `jarvis-manual.1.f7gf6o64mlrmdzj4tvwpt21yr` — con la imagen `backend_backend:latest`, el patrón de nombre exacto que genera `docker-compose up` al correrlo a mano dentro de la carpeta `backend/` de este proyecto. Eran sobras de una prueba manual en el VPS, de algún punto anterior de la vida del proyecto, que nunca se limpiaron.

`docker inspect jarvis-manual --format '{{json .Config.Labels}}'` confirmó la causa exacta:
```json
{
  "traefik.docker.network": "easypanel",
  "traefik.enable": "true",
  "traefik.http.routers.jarvis-manual.rule": "Host(`app-jarvisplanner.hzedxy.easypanel.host`) && PathPrefix(`/api`)",
  "traefik.http.routers.jarvis-manual.tls": "true",
  "traefik.http.routers.jarvis-manual.tls.certresolver": "letsencrypt",
  "traefik.http.services.jarvis-manual.loadbalancer.server.port": "80"
}
```
Ese contenedor viejo tenía una regla de Traefik para **exactamente el mismo `Host` y `PathPrefix`** que el contenedor real — dos backends distintos (uno actualizado, uno de hace días) compitiendo por el mismo tráfico. Traefik alternaba entre ambos sin ningún patrón predecible desde afuera, lo que explica todo lo observado: a veces código nuevo, a veces código viejo (`minBuildNumber: 1` en vez de `2`), a veces 404 franco (posible confusión interna de Traefik al tener dos definiciones de router en conflicto para la misma regla). Encaja también con por qué un simple restart del servicio en EasyPanel (que solo toca el contenedor `app_jarvisplanner`) no arregló nada — el contenedor huérfano seguía ahí, sin que EasyPanel supiera de su existencia.

**Arreglo:** `docker stop` de los tres contenedores huérfanos, confirmado con 40 peticiones seguidas exitosas en 80 segundos (antes fallaba el 100% del tiempo en rachas de más de un minuto), y luego `docker rm` para no dejarlos ni siquiera detenidos. Nada de esto tocó el contenedor real ni la base de datos.

**Lección para no repetirlo:** si en el futuro se necesita correr `docker-compose up` a mano en el VPS para probar algo (fuera del flujo normal de EasyPanel), hay que acordarse de `docker-compose down` al terminar — y si alguna vez se le agregan labels de Traefik a un contenedor de prueba, hay que usar un `Host`/router name que no choque con el dominio de producción. El síntoma de este bug (rutas públicas fallando de forma intermitente, sirviendo a veces código viejo) es exactamente lo que hay que buscar si algo así vuelve a pasar: `docker ps -a` en el VPS (no solo en la consola del contenedor de EasyPanel) para ver **todos** los contenedores, no solo el que se cree que es el único.

## Pantalla de Notas: local por diseño, no una caché de algo del backend

22 de septiembre de 2026. Se agregó una pestaña "Notas" (`notes_screen.dart`) para que el usuario anote pendientes del día a día, con un mensaje destacado arriba pidiéndole explícitamente que la use para eso.

Se decidió que viviera **100% en el dispositivo** (mismo patrón de `SharedPreferences` que la caché de blueprint/historial en `getNotes()`/`saveNotes()`), sin endpoint ni tabla nueva en el backend. Motivo: es texto del usuario para sí mismo, sin ningún valor en sincronizarlo entre dispositivos ni en que el backend lo procese — agregar un endpoint solo habría sumado superficie de red (con el backend históricamente inestable, ver arriba) sin ningún beneficio real. Diferencia importante con blueprint/historial: esos sí son una *caché* de algo que también existe en el servidor (si se pierde la copia local, se puede volver a pedir); las notas son la **única** copia que existe — si se pierden localmente, se pierden de verdad. Eso hizo más importante todavía el siguiente punto (aislamiento por cuenta) para no perderlas por accidente al cambiar de cuenta en el mismo teléfono.

## Caché local (blueprint, historial, notas) aislada por cuenta, no por dispositivo

22 de septiembre de 2026, a raíz de una pregunta directa del usuario: *"¿qué pasa si el teléfono tiene dos cuentas, cada base de datos local corresponde a la cuenta correcta?"*

Antes de este cambio, las tres llaves de `SharedPreferences` (`local_blueprint_cache`, `local_history_cache`, `local_notes`) eran fijas por dispositivo. En la práctica esto **no llegaba a mezclar datos entre cuentas** porque `logout()` siempre las borraba (tanto al cerrar sesión manualmente como al expirar el token vía `_reportIfUnauthorized` → `logout()` automático) — pero era correcto por comportamiento implícito, no por diseño: cualquier futuro camino que cambiara de cuenta sin pasar por `logout()` (ej. un eventual "cambio rápido de cuenta") habría dejado ver datos de la cuenta anterior a la nueva.

**Arreglo:** cada llave ahora lleva de sufijo el `userId` (`ApiService._scopedKey()`), leído decodificando el payload del JWT ya guardado (`_decodeAccountId`) — sin verificar la firma, porque no hace falta: no es un chequeo de seguridad, solo una llave local, y el backend ya valida el token de verdad en cada request. Con esto, cada cuenta lee y escribe su propio cajón aunque en algún momento se deje de limpiar en logout, y como beneficio adicional alguien que vuelve a entrar a una cuenta que ya usó antes en ese mismo teléfono vería sus datos al instante en vez de partir en blanco (aunque hoy `logout()` sigue borrando la copia de la cuenta que cierra sesión, sin cambios de comportamiento ahí).

**Migración:** quien ya tenía datos guardados bajo la llave vieja sin sufijo (sobre todo relevante para notas, que no tienen respaldo en el backend) no los pierde de vista — `loadStoredToken()` corre `_migrateLegacyCacheKeys()` una sola vez por dispositivo, copiando lo que encuentre bajo la llave vieja a la llave nueva con `userId` ya resuelto, y borrando la vieja.
