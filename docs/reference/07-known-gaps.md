# 07 — Huecos conocidos y roadmap

Última revisión: 20 de septiembre de 2026. Esto es una lista viva — cuando se resuelva algo, se mueve a "Resuelto" o se borra; cuando surja algo nuevo, se agrega aquí en vez de quedar solo en la memoria de una conversación.

## 🔴 Antes de que gente real dependa de la app

0. **El backend en producción está inestable — SIN DIAGNOSTICAR ni resolver todavía (2026-09-22).** Confirmado con `curl` directo contra `https://app-jarvisplanner.hzedxy.easypanel.host`: en la misma ventana de minutos, `GET /api/version` (público, sin auth) respondió 200 unas veces y 404 "Cannot GET" otras, y en un punto **todas** las rutas probadas (incluidas públicas) devolvieron 404 a la vez — señal de que el contenedor se está reiniciando/cayendo de forma intermitente, posiblemente un deploy que quedó a medias o un crash-loop. También se confirmó que el backend en vivo estaba sirviendo `minBuildNumber: 1` (versión vieja) en vez de `2` (la última pusheada), o sea que el último deploy tampoco se aplicó limpiamente. **Pendiente: revisar en EasyPanel el estado del último deploy y los logs del contenedor para encontrar la causa raíz del crash-loop.** Mientras tanto se agregó una caché local persistente en el frontend (ver [06-decisions.md](06-decisions.md)) para que la app siga siendo usable con datos "viejos" aunque el backend esté caído — es una mitigación, no una solución; escrituras nuevas (plan del día, chequeos de energía, cambios de cuenta) siguen dependiendo de que el backend responda.
1. **No hay recuperación de contraseña.** Sin servicio de email configurado (decisión consciente, ver [06-decisions.md](06-decisions.md)), si un usuario olvida su contraseña queda bloqueado permanentemente — no hay flujo de "olvidé mi contraseña". Única salida actual: intervención manual en la base de datos.
2. **No hay respaldo (backup) de la base de datos.** Todo vive en un solo archivo SQLite en el volumen Docker del VPS. Si el disco falla o el volumen se desconfigura en un redeploy, se pierde todo permanentemente — cuentas, blueprints, historial.

## 🟡 Recomendado, no bloqueante

3. Confirmar una compilación **release** (no debug) funcionando de punta a punta en un dispositivo real — el crash de pantalla blanca ya se arregló, pero conviene una prueba explícita en modo release.
4. No hay reportes de errores/crashes (Sentry, Firebase Crashlytics o similar) — si la app le falla a un usuario, no hay forma de enterarse salvo que lo reporte.
5. Sin alerta de presupuesto en el dashboard de OpenRouter — el rate limiting interno protege contra bugs en bucle, pero no hay techo de gasto configurado del lado del proveedor.
6. El número de versión (`pubspec.yaml` → `version: 1.0.0+1`) sigue en su valor inicial. Ahora tiene más peso que antes: desde el mecanismo de actualización forzada (ver [06-decisions.md](06-decisions.md)), el `+N` (build number) debe mantenerse sincronizado a mano con `kAppBuildNumber` (`frontend/lib/core/app_info.dart`) en cada release — si se te olvida subir alguno de los dos, el chequeo de versión obsoleta queda desalineado. Además, Android sigue necesitando que ese número suba en cada build para reconocer que es una actualización real.
7. Cobertura de tests del frontend es un solo smoke test (`test/widget_test.dart`). El backend tiene cobertura real (9 suites / 32 tests); el frontend no.
8. No hay CI (los tests y `flutter analyze`/`tsc --noEmit` se corren manualmente en cada sesión de edición, no automático en cada push).

## ✅ Resuelto

- ~~La Política de Privacidad solo vive dentro de la app~~ — ya existe una copia pública en `website/privacidad.html`, pensada exactamente para el campo de URL que pide Play Console. Falta solo publicar el sitio (ver `website/README.md`) para que esa URL sea real.

## 🟢 Si algún día se apunta a Google Play (no evaluado todavía)

- Firma de release con keystore propio (hoy se asume debug-signed o sin verificar).
- Cuestionario de clasificación de contenido de Play Console — relevante porque la app toca temas de salud mental en el brief.
- Formulario de "Data Safety" de Play Store (qué datos se recogen, con quién se comparten — ya está documentado en [02-backend.md](02-backend.md) y en `/legal`, solo faltaría trasladarlo al formulario de la tienda).
- Assets de listado: ícono ya existe, y ya hay 2 capturas reales (`website/assets/screenshots/`) reusables como base — faltaría un gráfico de feature y la descripción corta/larga formal para la ficha de la tienda.
- Soporte iOS no evaluado — el proyecto Flutter trae los archivos de iOS por defecto pero nunca se ha compilado ni probado ahí.

## Ideas de mejora (no huecos de lanzamiento, mejoras futuras)

- **Brief**: nada pendiente por ahora — ya tiene revisión antes de confirmar, botón de saltar/volver, y respaldo offline.
- **Costo de IA**: el rate limiting cubre `/assessment`, `/daily-plan`, `/midday`; si el uso crece, revisar si hace falta un límite también a nivel de cuenta (no solo IP) para evitar que una sola cuenta comprometida genere costo desproporcionado.
- **Cuenta**: ya tiene editar nombre, cambiar contraseña, eliminar cuenta, avatar, horas de notificación configurables. Sin pendientes obvios salvo recuperación de contraseña (ver arriba).
- **Historial**: ya tiene racha, promedio semanal, gráfico de barras, y predicción de energía por día de la semana. Si se quiere ir más allá, lo siguiente natural sería correlacionar energía con qué tan seguido se completan las tareas del día, no solo mostrar energía sola.
- **Notificaciones**: horas configurables ya existen; podría agregarse un "modo silencio" temporal (vacaciones/descanso) sin tener que desactivar permisos del sistema.
