# Sitio web de Jarvis Planeador

Landing page estática (HTML + CSS puro, sin build ni dependencias) para descargar el APK de Jarvis Planeador.

```
website/
  index.html          — landing principal
  privacidad.html      — Política de Privacidad y Términos (mismo texto que /legal dentro de la app)
  css/styles.css
  assets/
    logo.png                    — ícono de la app (copiado de frontend/assets/icon/app_icon.png)
    screenshots/
      blueprint.jpg              — captura de "Mi Plan Maestro"
      daily-plan.jpg              — captura del plan diario (bloque "Al final del día")
```

## Activar el botón de descarga

El botón "Descargar APK" apunta a:
```
https://github.com/Rodildo/jarvis-planeador/releases/latest/download/jarvis-planeador.apk
```

Esa URL de GitHub **siempre sirve el asset con ese nombre exacto del release más reciente** — no hay que tocar el HTML nunca más una vez configurado. Para activarlo:

1. Compila el APK desde Android Studio (como siempre, nunca en segundo plano — ver `AGENTS.md`).
2. En GitHub, ve a `Releases` → `Draft a new release`.
3. Sube el `.apk` compilado y renómbralo (o el asset) exactamente a `jarvis-planeador.apk`.
4. Publica el release.

Cada vez que saques una versión nueva, solo repite los pasos 1-4 con un release nuevo — el link de la landing no cambia.

**Alternativa** si no quieres usar GitHub Releases: sube el `.apk` a `website/assets/jarvis-planeador.apk` y cambia el `href` de los dos botones de descarga en `index.html` a `assets/jarvis-planeador.apk`. Más simple, pero el archivo queda versionado en git (pesa varias decenas de MB) y hay que reemplazarlo a mano en cada release.

## Publicar el sitio

Es HTML/CSS estático puro — no necesita build ni servidor con lógica. Cualquiera de estas opciones sirve tal cual:

- **GitHub Pages** (más simple, gratis): en la configuración del repo, `Settings → Pages`, elegir la rama `main` y la carpeta `/website` (o mover el contenido a una rama `gh-pages`/carpeta `docs` si GitHub Pages de tu plan lo exige así).
- **EasyPanel**: crear un nuevo servicio de tipo "sitio estático" apuntando a esta carpeta.
- Netlify, Vercel, o arrastrar la carpeta a cualquier hosting estático.

## Capturas de pantalla

Las capturas actuales (`assets/screenshots/`) son reales, tomadas del dispositivo del usuario. Si la UI de esas pantallas cambia en el futuro, hay que volver a tomarlas y reemplazar esos dos archivos (mismo nombre, mismas proporciones ~763×1600 funciona bien con el marco de teléfono en CSS).
