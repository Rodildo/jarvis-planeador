# Documentación de referencia — Jarvis Planeador

Esta carpeta es el contexto técnico completo y actualizado de la app, pensado para que una sesión de edición futura (humana o de IA) pueda retomar el proyecto sin tener que releer todo el código desde cero.

**¿Buscas los links del repo, del APK, o las reglas de flujo de trabajo (cuándo hacer push, cuándo recordar el deploy)?** Eso vive en [PROYECTO.md](../../PROYECTO.md), en la raíz del repo — es el punto de entrada rápido. Esta carpeta es el detalle técnico profundo al que ese documento apunta.

**A diferencia de `docs/superpowers/` (specs/planes originales del diseño inicial, del 17 de septiembre de 2026, ya desactualizados en varios puntos) y de `procesos_historial.txt` (bitácora histórica de la Fase 1-2, también desactualizada), estos documentos reflejan el estado ACTUAL del código.** Si algo aquí contradice esos archivos viejos, este documento tiene razón — esos son historia, no verdad vigente.

## Índice

1. [01-overview.md](01-overview.md) — Qué es la app, para quién, stack tecnológico, estado actual.
2. [02-backend.md](02-backend.md) — Cada endpoint de la API, esquema completo de la base de datos, modelo de auth/seguridad.
3. [03-frontend.md](03-frontend.md) — Cada pantalla, cada provider, rutas, almacenamiento local, notificaciones.
4. [04-data-model.md](04-data-model.md) — El banco de 50 preguntas, el esquema del Life Blueprint, el esquema del plan diario.
5. [05-deployment.md](05-deployment.md) — Variables de entorno, Docker, flujo de despliegue en EasyPanel.
6. [06-decisions.md](06-decisions.md) — Por qué se hizo cada cosa de la forma en que está, no solo qué se hizo.
7. [07-known-gaps.md](07-known-gaps.md) — Lo que falta antes de un lanzamiento real, e ideas de mejora pendientes.

## Cómo mantener esto vivo

Cuando se edite el código de forma que alguno de estos documentos quede desactualizado (nuevo endpoint, nueva pantalla, cambio de esquema de datos, nueva decisión de arquitectura importante), hay que actualizar el archivo correspondiente en el mismo cambio — no dejarlo para después. Un documento de referencia que miente es peor que no tener documento.

**Última actualización:** 23 de septiembre de 2026, después de: las notas de texto pasaron de vivir solo en el dispositivo a sincronizarse con el backend (tabla `notes` + `GET/POST/PUT/DELETE /notes`), corrigiendo que se perdieran para siempre al cerrar sesión — la copia local se queda, pero ahora es solo caché para carga instantánea, no el único lugar donde existen (ver [06-decisions.md](06-decisions.md)). Un día antes: nueva pestaña de Notas (todavía local en ese momento) y caché local (blueprint/historial/notas) aislada por cuenta en vez de por dispositivo, con migración automática de lo que ya hubiera guardado; encontrada y resuelta la causa real del backend inestable (contenedores Docker huérfanos de una prueba manual, meses atrás, compitiendo con Traefik por la misma ruta que el contenedor real); caché local persistente en el frontend para Plan Maestro/Historial; timeouts explícitos en las 19 llamadas de red del frontend; el primer forzado real de actualización obligatoria (build #2); soporte bilingüe español/inglés completo (interfaz + contenido generado por IA); mecanismo de versión obsoleta forzada; confirmación con contraseña antes de regenerar el Life Blueprint; y "nunca pantallas vacías" en Plan Maestro/Historial. Antes de eso: multiusuario con auth real, brief de 50 preguntas con banco fijo, plan diario en 3 bloques, notificaciones 3x/día, historial con predicción de energía, foto de perfil, y política de privacidad/términos.
