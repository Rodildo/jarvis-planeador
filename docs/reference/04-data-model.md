# 04 — Modelo de datos

## Las 5 áreas de vida (`LIFE_AREAS`)

Definidas en **dos lugares que deben mantenerse sincronizados manualmente** (no hay una fuente única compartida entre backend y frontend):
- Backend: `backend/src/ai/gemini.ts` → `LIFE_AREAS`
- Frontend: `frontend/lib/core/onboarding_questions.dart` (claves `_salud`, etc.) y `frontend/lib/blueprint_screen.dart` (`_areaInfo`, que además le pone un ícono a cada una)

| `key` | Label |
|---|---|
| `salud` | Salud física y mental |
| `carrera_finanzas` | Carrera y finanzas |
| `relaciones` | Relaciones y familia |
| `crecimiento` | Crecimiento personal y hábitos |
| `proposito` | Propósito y visión de vida |

Si se agrega/renombra un área, hay que tocar los 3 lugares de arriba.

## El banco de 50 preguntas (`frontend/lib/core/onboarding_questions.dart`)

10 preguntas por área, mezclando 3 tipos para que no se sienta como un formulario repetitivo:

| Tipo | UI | Se guarda como |
|---|---|---|
| `text` | campo de texto libre | el texto tal cual |
| `scale` | 5 botones circulares 1-5, con etiqueta opcional en los extremos (`scaleLowLabel`/`scaleHighLabel`) | el número como string ("4") |
| `choice` | chips con 2-3 opciones, tap = respuesta inmediata | el texto exacto de la opción elegida |

Distribución real por área (no es uniforme a propósito — las áreas más "narrativas" como propósito tienen más texto libre):

| Área | scale | choice | text |
|---|---|---|---|
| Salud | 2 | 3 | 5 |
| Carrera y finanzas | 1 | 3 | 6 |
| Relaciones | 1 | 2 | 7 |
| Crecimiento | 2 | 2 | 6 |
| Propósito | 1 | 1 | 8 |
| **Total** | **7** | **11** | **32** |

El texto exacto de cada pregunta vive únicamente en el código fuente (`onboardingQuestions`) — este documento no lo duplica para no arriesgar que quede desincronizado; ese archivo es la fuente de verdad.

**Ninguna pregunta asume una condición de salud específica.** Antes había preguntas que mencionaban "tu bipolaridad" directamente (la app nació pensada para un solo usuario bipolar); se generalizaron para ser abiertas y aplicables a cualquier persona — ver [06-decisions.md](06-decisions.md).

## El brief como transcript (`messages`)

En memoria (`OnboardingProvider.messages`) y en el backend (`onboarding_progress.messages`), el brief es un array plano que alterna roles:

```json
[
  { "role": "jarvis", "text": "¿Cómo describirías tu energía física en un día promedio?" },
  { "role": "user", "text": "4" },
  { "role": "jarvis", "text": "¿Duermes lo que necesitas normalmente?" },
  { "role": "user", "text": "Más o menos" },
  ...
]
```

Índice par = pregunta de Jarvis, índice impar = respuesta del usuario. `messages[2i]` es la pregunta i-ésima, `messages[2i+1]` su respuesta — así es como `reviewPairs` y `updateAnswer(pairIndex, ...)` en `OnboardingProvider` encuentran cada par sin necesitar IDs.

## El Life Blueprint (`blueprints.blueprint_data`, generado por `generateBlueprint`)

```json
{
  "life_vision": "Síntesis breve y potente del propósito y visión de vida del usuario",
  "areas": {
    "salud": { "summary": "string", "goals": ["string", "string", "string"] },
    "carrera_finanzas": { "summary": "string", "goals": [...] },
    "relaciones": { "summary": "string", "goals": [...] },
    "crecimiento": { "summary": "string", "goals": [...] },
    "proposito": { "summary": "string", "goals": [...] }
  },
  "daily_routine": "Descripción de 2-3 frases de cómo debería verse un día ideal"
}
```

Cada área: 2-4 metas (`goals`), según le pide el prompt a la IA (no hay validación estricta de ese rango en el backend, es solo la instrucción del prompt).

En un re-brief mensual, el blueprint anterior se le pasa a la IA como contexto (`previousBlueprint` en `generateBlueprint`) para que **evolucione** las metas en vez de generar uno desde cero — puede conservar metas que siguen vigentes.

## El plan diario (`generateDailyPlan`, se muestra en `ChatScreen` pero NO se guarda tal cual — ver abajo)

```json
{
  "greeting": "Mensaje motivacional corto y empático",
  "morning": [ { "task": "Acción concreta", "reason": "por qué, ligada a una meta" } ],
  "midday": [ { "task": "...", "reason": "..." } ],
  "night": [ { "task": "...", "reason": "..." } ]
}
```

Cada lista tiene entre 1 y 4 tareas, menos y más simples si la energía reportada es baja.

## El estado del día (`daily_logs.actions_chosen`, lo que de verdad persiste)

Lo que realmente se guarda en cada cambio (`ChatProvider._persistState()` → `POST /daily-actions`) es un envoltorio más grande que el plan puro:

```json
{
  "plan": { "greeting": "...", "morning": [...], "midday": [...], "night": [...] },
  "completed": { "ai-morning-0": true, "ai-midday-1": false, "manual-1758312345678901": true },
  "manualTasks": [
    { "id": "manual-1758312345678901", "block": "midday", "text": "Comprar víveres" }
  ]
}
```

- Claves de `completed`: `"ai-<block>-<index>"` para tareas generadas por la IA (el índice es su posición en la lista de ese bloque), o el `id` propio de una tarea manual (que ya trae el prefijo `manual-`).
- `manualTasks[].id` = `'manual-${DateTime.now().microsecondsSinceEpoch}'` — generado en el cliente, nunca en el backend.
- **Se sobreescribe entero en cada guardado.** No hay operación de "solo actualizar esta tarea" en el backend — el cliente manda el objeto completo cada vez.

## Avatar (`users.avatar`)

Un data URI completo, tal cual lo produce `image_picker` + `base64Encode`:

```
data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD...
```

- El cliente lo redimensiona a máx. 512×512 y comprime a calidad 70 **antes** de mandarlo (parámetros de `ImagePicker.pickImage`).
- El backend valida que empiece con `data:image/` y que el string completo no pase de 1,000,000 caracteres (~750KB reales en base64) — 400/413 si no cumple.
- No hay procesamiento de imagen en el backend (no se re-comprime, no se genera miniatura) — se guarda el string tal cual llega.

## Formato de fechas

Todas las fechas de `daily_logs` (`date`, y por extensión las fechas que manda el frontend en `/daily-plan`, `/midday`, `/daily-actions`) son strings `YYYY-MM-DD`, generadas en el cliente con `DateTime.now().toIso8601String().split('T')[0]` — **hora local del dispositivo**, no UTC. Los timestamps (`created_at`, `updated_at`, `morning_time`) sí son `CURRENT_TIMESTAMP` de SQLite, que es UTC.
