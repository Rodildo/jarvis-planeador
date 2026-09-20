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
