# Guía del proyecto — Jarvis Planeador

Punto de entrada rápido: qué es esto, dónde está todo, y las reglas de trabajo acordadas para cualquier sesión (humana o de IA) que retome el proyecto. Para el detalle técnico profundo (endpoints, esquema de datos, providers, decisiones de diseño), ver [docs/reference/](docs/reference/README.md) — este documento no reemplaza esos, los resume y les da contexto operativo.

## Qué es

**Jarvis Planeador** (marca: Kinetiqsystem) es una app Android en Beta que genera un plan de vida ("Life Blueprint") a partir de un brief de 50 preguntas, y luego genera un plan diario en 3 bloques (mañana/mediodía/noche) adaptado al nivel de energía que el usuario reporta cada día — pensada originalmente para energía muy variable día a día (bipolaridad), generalizada para cualquier usuario. Detalle completo en [docs/reference/01-overview.md](docs/reference/01-overview.md).

## Links importantes

| Qué | Link |
|---|---|
| Repositorio (GitHub) | https://github.com/Rodildo/jarvis-planeador |
| Backend en producción (EasyPanel) | https://app-jarvisplanner.hzedxy.easypanel.host |
| Descarga del APK (siempre la última versión publicada) | https://github.com/Rodildo/jarvis-planeador/releases/latest/download/jarvis-planeador.apk |
| Release de GitHub donde vive ese APK | https://github.com/Rodildo/jarvis-planeador/releases/tag/v1.0.0-beta |
| Página web (landing + descarga + política de privacidad) | Existe como sitio estático en [`website/`](website/), **todavía no está publicada en un dominio público** — falta decidir hosting (GitHub Pages, EasyPanel como sitio estático, u otro). Ver [website/README.md](website/README.md) para los pasos de publicación. |

## Reglas de trabajo acordadas con el usuario

Estas reglas están pre-autorizadas — no hay que pedir permiso cada vez que aplican, salvo que se indique lo contrario.

1. **Nunca compilar el APK** (`flutter build apk` ni equivalentes) en segundo plano ni sin permiso explícito. Eso lo hace el usuario desde Android Studio. Ver [AGENTS.md](AGENTS.md) — regla dura del proyecto, no negociable.
2. **Cada vez que se modifica algo en `backend/`**: verificar con `cd backend && npx tsc --noEmit && npx jest`, y si pasa, hacer `git commit` + `git push origin main` automáticamente al terminar, sin esperar a que el usuario lo pida. Después del push, **recordarle siempre que entre a EasyPanel y le dé clic a "Deploy"** — el push por sí solo no auto-despliega de forma confiable ahí.
3. **Cada vez que se modifica algo en `frontend/`**: verificar con `cd frontend && flutter analyze lib test && flutter test test/widget_test.dart`. No hay push automático obligatorio para cambios solo de frontend (a diferencia del backend), pero sí hay que **recordarle al usuario que recompile el APK desde Android Studio** para poder probar el cambio en su teléfono.
4. **Cuando el usuario pida "actualiza el APK en la web/GitHub"**: nunca compilar nada — tomar el `.apk` que el usuario ya compiló (normalmente en `frontend/build/app/outputs/flutter-apk/app-release.apk`), y subirlo como asset al release `v1.0.0-beta` en GitHub, reemplazando el existente y manteniendo el nombre exacto `jarvis-planeador.apk` (el link de descarga de arriba y el botón de la landing apuntan a `releases/latest/download/jarvis-planeador.apk`, que siempre resuelve al asset con ese nombre del release más reciente — no hay que tocar ningún link cuando se actualiza el archivo). Como no hay `gh` CLI instalado, esto se hace con la API REST de GitHub vía `curl`, reutilizando el token ya guardado en Git Credential Manager (`git credential fill`) — nunca pedir uno nuevo ni imprimirlo en la salida.
5. **Documentación viva**: si un cambio de código deja desactualizado algo en `docs/reference/`, actualizar el archivo correspondiente en el mismo cambio, no después.
6. **Forzar actualización obligatoria** ("que las versiones anteriores tengan que actualizar"): recordar que esto **no puede ser retroactivo** — solo afecta a quien ya tenga una build igual o posterior a la #1 (la que estrenó el mecanismo, publicada 2026-09-21). Si el usuario lo pide para una build futura: primero publicar el `.apk` nuevo con su `kAppBuildNumber` ya subido, y **solo después** subir `MIN_SUPPORTED_BUILD_NUMBER` en el backend — nunca al revés, o la build que la gente debería poder descargar queda bloqueada también. Pasos exactos en [docs/reference/05-deployment.md](docs/reference/05-deployment.md).
7. **"Sube el APK" NUNCA implica forzar actualización — regla explícita del usuario, no negociable.** Confirmada dos veces el 2026-09-21: primero la seguí por iniciativa propia, y después el usuario la dio como orden permanente ("de ahora en adelante solo fuerza la actualización cuando yo te dé la orden de dejar todas las versiones anteriores desactualizadas"). Por defecto, ante "compilé, súbelo"/"actualízalo": subir el `.apk` reemplazando el asset del release tal cual, **sin tocar `MIN_SUPPORTED_BUILD_NUMBER` bajo ninguna circunstancia**, salvo que el usuario lo pida con una orden explícita de ese tipo ("fuerza la actualización", "deja la vieja versión inservible", "que actualicen sí o sí"). Quien ya tenga esa misma build instalada simplemente no se entera de que hay un `.apk` más nuevo hasta que reinstale — eso es lo esperado, no un descuido. Cuando sí se pida forzar (regla 6): antes de subir el APK, **verificar que el número de build realmente cambió** en el archivo compilado (por ejemplo extrayendo `AndroidManifest.xml` del `.apk` con `unzip` y buscando la versión ahí) — ya pasó que el usuario compiló antes de que el número se subiera en el código, y el `.apk` "nuevo" resultó ser indistinguible del anterior. Guardado también como memoria persistente (`workflow_apk_force_update`), para que esta regla no dependa de releer esta conversación.

## Últimas actualizaciones (más reciente primero)

- **2026-09-21** — El usuario confirmó como orden permanente que "sube el APK" nunca fuerza actualización por sí solo (regla 7 arriba) — solo se toca `MIN_SUPPORTED_BUILD_NUMBER` cuando lo pide explícitamente. Guardado también en memoria persistente para que no dependa de esta conversación.
- **2026-09-21** — Arreglada la causa real de que "Mi Plan Maestro" (y en general la app) se quedara colgada o muy lenta al reabrir tras un rato cerrada: **ninguna de las 19 llamadas de red del frontend tenía timeout explícito**, así que una conexión lenta en reconectar podía hacer que un solo intento se quedara esperando el default del sistema operativo en vez de fallar rápido y reintentar. Se agregó `.timeout(...)` a todas (12s la mayoría, 30s para subir avatar, 90s para las 3 que dependen de la IA). Publicado en el Release de GitHub — **esta vez sin forzar actualización** (el usuario no lo pidió; el `.apk` sigue etiquetado como build #2, mismo `MIN_SUPPORTED_BUILD_NUMBER` de antes, así que quien ya tenga la build #2 instalada no ve ningún aviso hasta que reinstale manualmente). Detalle en [docs/reference/06-decisions.md](docs/reference/06-decisions.md).
- **2026-09-21** — Primer uso real del bloqueo de actualización obligatoria: se publicó la build #2 (`kAppBuildNumber = 2`, `pubspec.yaml` → `1.0.1+2`, incluye el arreglo de reintento cada 3s en Plan Maestro/Historial) en el Release de GitHub, y se subió `MIN_SUPPORTED_BUILD_NUMBER = 2` en el backend. Cualquiera que siga en la build #1 ve la pantalla de actualización obligatoria hasta que instale esta build. Nota operativa real: la build #1 ya estaba publicada con el número sin subir cuando se pidió forzar la actualización por primera vez — hubo que subir `kAppBuildNumber`/`pubspec.yaml` a mano, pedir una recompilación nueva, y solo entonces se pudo forzar. Detalle en [docs/reference/06-decisions.md](docs/reference/06-decisions.md) y [docs/reference/05-deployment.md](docs/reference/05-deployment.md).
- **2026-09-21** — La build con soporte bilingüe se compiló, se probó, y se publicó como `kAppBuildNumber = 1` — la primera build con el mecanismo de versión obsoleta, sin forzado activo todavía (ver entrada de arriba para cuando sí se activó).
- **2026-09-21** — Soporte bilingüe completo español/inglés (selector en el primer arranque, editable en "Mi Cuenta"; incluye el contenido generado por IA). Botón "agregar tarea" más visible. Regenerar el Life Blueprint ahora pide confirmación + contraseña. "Mi Plan Maestro" e "Historial" nunca muestran un estado vacío (siempre cargando en vez de "no hay nada"). Mecanismo de versión obsoleta: el backend puede forzar que los usuarios actualicen, bloqueando la app con un link de descarga. Ver [docs/reference/06-decisions.md](docs/reference/06-decisions.md) para el detalle completo. *(backend desplegado; frontend compilado y publicado, ver entrada de arriba)*
- **2026-09-20** — El botón manual "Chequeo de energía ahora" ahora respeta un mínimo de 6 horas desde el último reporte de energía (antes estaba siempre disponible); al elegir un nivel de energía, la app ahora muestra "Cargando... por favor espera" y atenúa los botones mientras procesa. *(frontend)*
- **2026-09-20** — Corregido que la pantalla de "¿cómo está tu energía?" reapareciera cada vez que se cerraba y abría la app: reintentos en la carga del plan de hoy, respaldo local como red de seguridad, y un límite duro de máximo 2 veces al día con al menos 8 horas de diferencia. *(frontend)*
- **2026-09-20** — El chequeo de energía a mitad de día ahora puede **regenerar las tareas restantes** (mediodía/noche) con IA cuando la energía cambia mucho, en vez de solo dar un mensaje. *(backend, desplegado)*
- **2026-09-20** — Landing page (`website/`) con fondo animado, capturas reales, y descarga de APK vía GitHub Releases.
- **2026-09-20** — Corregido bug de truncamiento de JSON en las llamadas a la IA (faltaba `max_tokens` explícito) que causaba fallos intermitentes al generar el plan diario.
- **2026-09-20** — Corregido que la energía se volviera a pedir en cada apertura de la app cuando la generación del plan había fallado a medias.
- **2026-09-19 / 2026-09-20** — Multiusuario con auth real (JWT + bcrypt), gestión de cuenta (avatar, cambio de contraseña, eliminar cuenta), rate limiting + fix de `trust proxy`, brief de 50 preguntas con banco fijo (ya no generado por IA en vivo), política de privacidad/términos, ícono de la app.

Para el detalle completo y el porqué de cada decisión, ver [docs/reference/06-decisions.md](docs/reference/06-decisions.md) y el historial real de commits (`git log`).

## Estructura del repo

```
/backend         — API Express + SQLite + integración con OpenRouter (ver docs/reference/02-backend.md)
/frontend        — App Flutter/Android (ver docs/reference/03-frontend.md)
/website         — Landing estática (descarga del APK + política de privacidad), no publicada aún
/docs/reference  — Documentación técnica viva (mantener actualizada en cada cambio relevante)
AGENTS.md        — Reglas de compilación (regla dura: nunca compilar en segundo plano)
```
