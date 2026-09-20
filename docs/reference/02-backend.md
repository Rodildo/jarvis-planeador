# 02 — Backend

Ubicación: `backend/src/`

```
src/
  index.ts       — bootstrap de Express (CORS, trust proxy, body limit, init de la DB)
  api/routes.ts  — TODAS las rutas de la API (un solo archivo, sin separar por controladores)
  auth/auth.ts   — hashing, JWT, middleware requireAuth, validación de email
  db/database.ts — todo el acceso a SQLite (funciones planas, sin ORM)
  ai/gemini.ts   — integración con OpenRouter (el nombre del archivo es histórico, no usa Gemini)
```

Corre con `ts-node` directo (sin build de TypeScript a JS — `npm run build` es un no-op literal). Ver [05-deployment.md](05-deployment.md) para cómo se despliega.

## Arranque (`index.ts`)

- `app.set('trust proxy', 1)`: **crítico**. EasyPanel sirve el backend detrás de Traefik. Sin esto, `req.ip` ve la IP del proxy en vez de la del cliente real, y todo el rate limiting por IP terminaría compartiendo un solo balde entre todos los usuarios de la app en vez de uno por persona. Hay un test dedicado a esto (`tests/api/trust-proxy.test.ts`) que falla si alguien lo quita.
- `express.json({ limit: '2mb' })`: el default de Express es 100kb, insuficiente para el avatar en base64 (ver más abajo).
- CORS abierto (`cors()` sin restricciones) — no hay whitelist de orígenes.

## Modelo de autenticación

- JWT firmado con `JWT_SECRET` (env var, sin default — el server no arranca sin ella), expira a los 90 días (`TOKEN_TTL` en `auth.ts`).
- Contraseñas con `bcryptjs`, 10 rounds.
- El middleware `requireAuth` se monta con `apiRouter.use(requireAuth)` **después** de las rutas de `/auth/register` y `/auth/login`, así que todo lo que está definido después en el archivo queda protegido automáticamente. El `userId` sale del token decodificado (`req.userId`), **nunca** de un parámetro o body — así un usuario no puede leer/escribir datos de otro así falsifique un ID en la petición.
- No hay recuperación de contraseña por email (no hay servicio de envío de correos configurado — ver [07-known-gaps.md](07-known-gaps.md)). Si alguien la olvida, queda bloqueado salvo intervención manual en la base de datos.

## Rate limiting (`express-rate-limit`, todo por IP real gracias a trust proxy)

| Limiter | Rutas | Límite |
|---|---|---|
| `registerLimiter` | `POST /auth/register` | 8 / 15 min |
| `loginLimiter` | `POST /auth/login` | 20 / 15 min |
| `aiCostLimiter` | `POST /assessment`, `POST /daily-plan`, `POST /midday` | 30 / hora |

`aiCostLimiter` existe porque esas 3 rutas le pegan a OpenRouter (cuestan dinero real por llamada) — protege tanto contra abuso como contra un bug del cliente que dispare llamadas en bucle.

## Endpoints

Todos bajo el prefijo `/api`. 🔓 = público. 🔒 = requiere `Authorization: Bearer <jwt>`.

### Auth y cuenta

| Método | Ruta | Auth | Descripción |
|---|---|---|---|
| GET | `/version` | 🔓 | `{ version }` — string fijo, se sube manualmente cuando se recuerda |
| GET | `/life-areas` | 🔓 | Devuelve `LIFE_AREAS` (las 5 áreas del brief, ver [04-data-model.md](04-data-model.md)) |
| POST | `/auth/register` | 🔓 | `{ email, password, firstName, lastName }` → crea cuenta, devuelve `{ token, userId, firstName, lastName }`. Valida formato de email, password ≥ 8 chars, email normalizado a minúsculas y `trim()`. 409 si el email ya existe. |
| POST | `/auth/login` | 🔓 | `{ email, password }` → `{ token, userId, firstName, lastName }` |
| POST | `/auth/change-password` | 🔒 | `{ currentPassword, newPassword }` — verifica la actual antes de cambiar |
| GET | `/profile` | 🔒 | `{ hasBlueprint, firstName, lastName, avatar }` — usado al arrancar la app para saber a dónde navegar |
| PATCH | `/profile` | 🔒 | `{ firstName, lastName }` — edita el nombre |
| PUT | `/profile/avatar` | 🔒 | `{ avatar }` (data URI `data:image/...;base64,...`) — 400 si no empieza con `data:image/`, 413 si pasa de `MAX_AVATAR_LENGTH` (1,000,000 chars ≈ 750KB) |
| DELETE | `/profile/avatar` | 🔒 | Quita el avatar (pone `NULL`) |
| DELETE | `/account` | 🔒 | `{ password }` — verifica contraseña, borra en cascada: blueprint, onboarding_progress, daily_logs, y la fila del usuario |

### Brief / Blueprint

| Método | Ruta | Auth | Descripción |
|---|---|---|---|
| GET | `/onboarding/progress` | 🔒 | Devuelve los mensajes del brief guardados (para retomar si se cerró la app a medias) |
| POST | `/onboarding/progress` | 🔒 | `{ messages }` — guarda el progreso en cada pregunta/edición (llamada en background, sin bloquear la UI) |
| POST | `/assessment` | 🔒 + `aiCostLimiter` | `{ answers }` (el array completo de 50 Q&A, serializado como string JSON dentro del campo) → genera el blueprint con la IA, lo guarda, y **limpia `onboarding_progress`** (así el próximo re-brief empieza limpio). Si ya existía un blueprint, se le pasa a la IA como contexto para que evolucione en vez de partir de cero (re-brief mensual). |
| GET | `/blueprint` | 🔒 | `{ blueprint, updatedAt }` — 404 si el usuario no ha completado su primer brief |

### Día a día

| Método | Ruta | Auth | Descripción |
|---|---|---|---|
| POST | `/daily-plan` | 🔒 + `aiCostLimiter` | `{ date, energyLevel }` → guarda `energy_morning`, genera el plan de 3 bloques con la IA (usa el nombre del usuario para el saludo) |
| POST | `/daily-actions` | 🔒 | `{ date, actions }` — `actions` es el estado completo del día (plan + tareas completadas + tareas manuales), se sobreescribe entero en cada cambio, no hay merge parcial |
| GET | `/daily-log/:date` | 🔒 | La fila cruda de `daily_logs` para esa fecha |
| POST | `/midday` | 🔒 + `aiCostLimiter` | `{ date, energyLevel }` → guarda `energy_midday`, genera un mensaje de ajuste con la IA basado en cómo cambió la energía |
| GET | `/history` | 🔒 | `?days=N` (default 30, tope 365) → lista de `daily_logs` ordenados DESC por fecha |

## Base de datos (SQLite, `db/database.ts`)

Un solo archivo (`DB_PATH`, default `./data/jarvis.sqlite`), modo `WAL`. Sin ORM — cada función abre su propio `db.prepare`/`db.run`/`db.get`. **No hay foreign keys con cascade configurado**: `deleteUserAccount` borra explícitamente de cada tabla, en orden.

### `users`
| Columna | Tipo | Notas |
|---|---|---|
| `id` | TEXT PK | `crypto.randomUUID()` |
| `email` | TEXT UNIQUE NOT NULL | normalizado a minúsculas antes de guardar |
| `password_hash` | TEXT NOT NULL | bcrypt |
| `first_name`, `last_name` | TEXT NOT NULL DEFAULT '' | agregadas después vía `ALTER TABLE` (migración silenciosa, ver abajo) |
| `avatar` | TEXT NULL | data URI completo (`data:image/jpeg;base64,...`), o NULL |
| `created_at` | DATETIME | default `CURRENT_TIMESTAMP` |

### `blueprints`
| Columna | Tipo | Notas |
|---|---|---|
| `user_id` | TEXT PK | |
| `blueprint_data` | TEXT NOT NULL | JSON serializado, ver [04-data-model.md](04-data-model.md) |
| `updated_at` | DATETIME | default `CURRENT_TIMESTAMP`; como `saveBlueprint` hace `INSERT OR REPLACE`, este campo se refresca solo en cada guardado (nunca se actualiza manualmente) — de ahí sale el "hace X días" del re-brief sugerido en la UI |

### `onboarding_progress`
| Columna | Tipo | Notas |
|---|---|---|
| `user_id` | TEXT PK | |
| `messages` | TEXT NOT NULL | JSON del array `[{role, text}, ...]` |
| `updated_at` | DATETIME | |

Se borra (`DELETE`) al completar un `/assessment` exitoso — no se deja basura de briefs viejos.

### `daily_logs`
| Columna | Tipo | Notas |
|---|---|---|
| `user_id`, `date` | TEXT | PK compuesta |
| `energy_morning`, `energy_midday` | INTEGER NULL | 1-5 |
| `morning_time` | DATETIME | se setea junto con `energy_morning` |
| `actions_chosen` | TEXT NULL | JSON del estado completo del día: `{ plan, completed, manualTasks }` (ver [04-data-model.md](04-data-model.md)) |

### Migraciones

No hay sistema de migraciones real. El patrón usado es: `CREATE TABLE IF NOT EXISTS` con el esquema completo actual, seguido de `ALTER TABLE ... ADD COLUMN` para cada columna agregada después, encadenados con callbacks que ignoran el error si la columna ya existe. Esto es deliberado y suficiente mientras el esquema no necesite cambios más complejos (renombrar columnas, cambiar tipos, etc.) — si llega ese caso, hay que escribir una migración de verdad.

## Integración con IA (`ai/gemini.ts`)

- `callOpenRouter(systemPrompt, userMessage, forceJson)`: hace el POST a OpenRouter, 3 reintentos con 1.5s de espera entre cada uno, usa `response_format: json_object` cuando `forceJson=true`.
- Modelo fijo: `deepseek/deepseek-v3.2` (constante `MODEL_NAME`, se cambió varias veces en el pasado — ver `procesos_historial.txt` para el porqué de cada cambio).
- `extractJson(text, label)`: extrae el primer `{...}` del texto devuelto por la IA con una regex y lo parsea — no confía en que la IA devuelva *solo* JSON limpio.
- **Único lugar donde se le habla a la IA sobre condiciones de salud**: el prompt de `generateDailyPlan` dice explícitamente "nunca asumas ni menciones un diagnóstico específico, solo responde a la energía reportada" — esto es deliberado, ver [06-decisions.md](06-decisions.md) (`bipolaridad` era hardcodeado antes y se generalizó).

Tres funciones exportadas, todas detalladas con su prompt completo en el archivo fuente:
- `generateBlueprint(answers, previousBlueprint?)`
- `generateDailyPlan(blueprint, energyLevel, userName?)`
- `generateMidDayAdjustment(blueprint, morningEnergy, middayEnergy, dailyPlan)`

## Tests

`backend/tests/`, con Jest. 9 suites, 31 tests a la fecha de este documento. Corren con `npm test`. Cobertura: auth (registro/login/cambio de contraseña/rate limiting/trust proxy), cuenta (perfil/avatar/eliminar), rutas de brief/blueprint/daily-plan, capa de IA (mockeada), y la capa de base de datos.
