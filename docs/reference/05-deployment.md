# 05 — Despliegue

## Backend: EasyPanel + Docker + Traefik

- Dominio productivo: `https://app-jarvisplanner.hzedxy.easypanel.host`
- El VPS corre EasyPanel, que pone Traefik como proxy reverso delante del contenedor Docker del backend.
- **Flujo de despliegue real: `git push origin main` → entrar a EasyPanel → botón "Deploy".** EasyPanel no siempre auto-despliega solo con el push; a veces hay que dispararlo manualmente desde la UI de la plataforma. Confirmar esto en cada release hasta que se automatice con un webhook.
- El backend corre con `ts-node` directo, **sin paso de build de TypeScript a JS** (`npm run build` es literalmente `echo "No build step needed for ts-node"`). El `Dockerfile` instala `typescript`/`ts-node` globalmente y arranca con `CMD ["ts-node", "src/index.ts"]`.

### `Dockerfile` (backend/Dockerfile)
```
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm install -g typescript ts-node
EXPOSE 80
CMD ["ts-node", "src/index.ts"]
```

### `docker-compose.yml` (uso local, EasyPanel gestiona su propio compose internamente)
```yaml
services:
  backend:
    build: .
    ports:
      - "80:80"
    volumes:
      - ./data:/app/data
    environment:
      - OPENROUTER_API_KEY=${OPENROUTER_API_KEY}
      - JWT_SECRET=${JWT_SECRET}
    restart: always
```

El volumen `./data:/app/data` es **el único mecanismo de persistencia** — ahí vive `jarvis.sqlite`. Si ese volumen no está correctamente montado en la configuración real de EasyPanel, cualquier redeploy borraría la base de datos. **No hay backup automático de este archivo** (ver [07-known-gaps.md](07-known-gaps.md)).

## Variables de entorno requeridas (backend)

| Variable | Requerida | Descripción |
|---|---|---|
| `OPENROUTER_API_KEY` | sí | API key de OpenRouter. Sin ella, cualquier llamada a la IA lanza `Error('OPENROUTER_API_KEY not configured')` |
| `JWT_SECRET` | sí | Sin ella el server **no arranca** llamadas autenticadas (`getJwtSecret()` lanza). Si se cambia el valor, todos los tokens ya emitidos quedan inválidos de inmediato — todos los usuarios tendrían que volver a iniciar sesión |
| `PORT` | no | default `80` |
| `DB_PATH` | no | default `./data/jarvis.sqlite` |

Puestas en `backend/.env` para desarrollo local (ese archivo está en `.gitignore`, nunca se commitea) y como env vars del contenedor en EasyPanel/`docker-compose.yml` para producción.

## Trust proxy — no tocar sin entender por qué

`backend/src/index.ts` tiene `app.set('trust proxy', 1)`. **Esto es obligatorio** porque EasyPanel pone el backend detrás de Traefik. Sin esto, `express-rate-limit` identifica a todos los usuarios como si vinieran de la misma IP (la del proxy), y el rate limiting por IP terminaría compartiendo un solo balde entre toda la app en vez de uno por persona. Hay un test (`backend/tests/api/trust-proxy.test.ts`) que reproduce el escenario con el header `X-Forwarded-For` y falla si este ajuste se revierte.

## Frontend: APK directo, no Play Store (todavía)

No hay pipeline de CI/CD ni distribución por tienda. El flujo actual es 100% manual:

1. Compilar desde **Android Studio** (`Build → Build APK` o correr con el celular conectado por USB). **No usar `flutter build apk` desde la terminal** — históricamente causó bloqueos de red del ISP contra `dl.google.com` y deadlocks de Gradle en Windows sin el JDK aislado de Android Studio (ver `procesos_historial.txt`, Fase 3, para el detalle completo del troubleshooting).
2. Según `AGENTS.md` (instrucciones del proyecto): **nunca compilar en segundo plano ni sin permiso explícito del usuario** — eso lo hace el usuario desde la interfaz de Android Studio, no un agente.
3. Instalar el `.apk` resultante directamente en el teléfono.

`frontend/lib/core/api_service.dart` apunta al dominio de EasyPanel por defecto (`baseUrl`), pero acepta override en tiempo de compilación vía `--dart-define=JARVIS_API_URL=...` si alguna vez se necesita apuntar a un backend local durante desarrollo.

### Forzar actualización (versión obsoleta)

Ver [06-decisions.md](06-decisions.md) para el diseño completo. Para forzar que todos los usuarios actualicen a una build nueva:
1. Subir `MIN_SUPPORTED_BUILD_NUMBER` en `backend/src/api/routes.ts` (endpoint `GET /version`) al build number de la build mínima aceptable.
2. Desplegar el backend como siempre (push + "Deploy" en EasyPanel).
3. Cualquier cliente con `kAppBuildNumber` (`frontend/lib/core/app_info.dart`) menor a ese valor queda bloqueado en `/update-required` hasta que instale la build nueva.

**`kAppBuildNumber` debe subirse a mano junto con el `+N` de `version:` en `pubspec.yaml` en cada release** — no hay nada que los mantenga sincronizados automáticamente, es responsabilidad de quien compila.

## Regla de trabajo acordada con el usuario

Cuando se modifica algo en `backend/`, el flujo esperado es: verificar (`tsc --noEmit` + `jest`), hacer commit y **push automáticamente sin que el usuario tenga que pedirlo cada vez**, y recordarle que tiene que ir a EasyPanel a darle "Deploy". Si el cambio es solo en `frontend/`, no aplica ningún push obligatorio ni recordatorio de deploy — el usuario recompila el APK cuando quiere probarlo.
