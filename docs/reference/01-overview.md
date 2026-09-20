# 01 — Overview

## Qué es

**Jarvis Planeador** (marca: Kinetiqsystem, app actualmente en Beta) es una app móvil Android que actúa como guía diario de vida adaptado al nivel de energía del usuario. Nació pensada específicamente para alguien con bipolaridad (energía muy variable día a día), pero se generalizó para cualquier usuario cuya energía/ánimo varíe (por la razón que sea) — ver [06-decisions.md](06-decisions.md) para el porqué de ese cambio.

El ciclo central:
1. El usuario completa un **brief de 50 preguntas** (una sola vez, y opcionalmente cada mes) sobre 5 áreas de su vida.
2. La IA genera un **Life Blueprint**: visión de vida + metas concretas por área.
3. Cada mañana el usuario reporta su energía (1-5) y la app genera un **plan del día en 3 bloques** (al levantarse / durante el día / al final del día), con tareas ligadas a sus metas reales, adaptadas a esa energía.
4. El usuario marca tareas completadas, puede agregar tareas propias, y opcionalmente hace un chequeo de energía a mitad de día que ajusta el tono del resto de la jornada.
5. Un historial guarda la energía diaria y permite ver patrones (racha, promedio semanal, predicción de energía de mañana por día de la semana).

## Para quién

Multiusuario con cuentas reales (email + contraseña). Cada usuario tiene su propio blueprint, historial y brief — no hay datos compartidos entre cuentas.

## Estado actual

**Beta.** Hay una auditoría de qué falta antes de un lanzamiento más serio en [07-known-gaps.md](07-known-gaps.md) — los dos puntos más importantes pendientes son recuperación de contraseña olvidada y respaldo (backup) de la base de datos.

## Stack tecnológico

| Capa | Tecnología |
|---|---|
| Frontend | Flutter (Dart), Android (iOS/otras plataformas existen por defecto de Flutter pero no se prueban ni se mantienen activamente) |
| Backend | Node.js + Express + TypeScript, corriendo con `ts-node` (sin paso de compilación) |
| Base de datos | SQLite (un solo archivo, elegido por simplicidad de despliegue más que por escala) |
| IA | OpenRouter (`deepseek/deepseek-v3.2`), no Gemini a pesar de que el archivo se sigue llamando `gemini.ts` por razones históricas |
| Hosting | VPS propio vía EasyPanel (Docker + Traefik como proxy reverso) |
| Notificaciones | 100% locales en el dispositivo (`flutter_local_notifications`), no hay servidor de push |

## Estructura del repo

```
/backend         — API Express + SQLite + integración con OpenRouter
/frontend        — App Flutter
/website         — Landing page estática (descarga del APK + Política de Privacidad pública)
/docs
  /reference      — ESTOS documentos (contexto técnico vigente)
  /superpowers    — Specs/planes originales del diseño inicial (histórico, desactualizado)
procesos_historial.txt — Bitácora de la Fase 1-2 del proyecto (histórico, desactualizado)
```

## Convención de nombres importante

El nombre de la app cambió de "Jarvis" a "**Jarvis Planeador**" durante el desarrollo. El asistente/persona dentro de la app se sigue llamando simplemente "Jarvis" (eso no cambia — es su nombre de personaje, no la marca del producto). El paquete Dart interno sigue llamándose `jarvis` (cambiarlo rompería todos los imports `package:jarvis/...`, no vale la pena).

## Idioma

Toda la UI, todos los mensajes de error de cara al usuario, y todos los prompts de IA están en **español**. El código (nombres de variables, comentarios técnicos) está mezclado inglés/español según lo que escribió cada sesión — no hay una convención estricta impuesta.
