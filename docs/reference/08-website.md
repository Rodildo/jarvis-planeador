# 08 — Website

Ubicación: `website/` (dentro del repo principal). HTML/CSS/JS puro, sin build, sin dependencias ni framework — landing de descarga del APK + Política de Privacidad pública.

```
website/
  index.html          — landing principal
  privacidad.html      — Política de Privacidad y Términos (mismo texto que /legal dentro de la app)
  robots.txt           — permite indexar todo, apunta al sitemap
  sitemap.xml           — las dos URLs del sitio, para Google Search Console
  CNAME                — dominio personalizado para GitHub Pages (www.jotaelebundle.com)
  css/styles.css       — todo el estilo, variables de color en :root, sin preprocesador
  js/background.js     — campo de estrellas animado del fondo (70 <span>, posición/duración al azar, sin dependencias, respeta prefers-reduced-motion)
  assets/
    logo.png                    — ícono de la app (copiado de frontend/assets/icon/app_icon.png), 246×246
    screenshots/
      blueprint.jpg              — captura real de "Mi Plan Maestro"
      daily-plan.jpg              — captura real del plan diario (bloque "Al final del día")
```

## Contenido de las páginas

- **`index.html`**: hero con CTA de descarga, sección de capturas de pantalla (2, dentro de un marco de teléfono en CSS), sección "Cómo funciona" (4 pasos), CTA final de descarga, footer con link a la política de privacidad.
- **`privacidad.html`**: texto legal completo (mismo contenido que `frontend/lib/legal_screen.dart` dentro de la app, mantenido sincronizado a mano — no hay una sola fuente de verdad compartida entre ambos).
- Botón de descarga (nav, hero y CTA final en `index.html`; nav en `privacidad.html`): apunta a `https://github.com/Rodildo/jarvis-planeador/releases/latest/download/jarvis-planeador.apk` — esa URL de GitHub siempre sirve el asset `jarvis-planeador.apk` del release más reciente, así que nunca hay que tocar el HTML al publicar una build nueva (ver [PROYECTO.md](../../PROYECTO.md), regla 4, para el paso de subir el `.apk`).

## SEO (agregado 23 de septiembre de 2026)

En `index.html` y `privacidad.html`:
- `<link rel="canonical">` (a `https://www.jotaelebundle.com/` y `.../privacidad.html`) y `<meta name="robots" content="index, follow">`.
- Open Graph (`og:type`, `og:site_name`, `og:locale`, `og:url`, `og:title`, `og:description`, `og:image`) y Twitter Card (`summary`), para que el link se vea bien al compartirlo.
- Solo en `index.html`: datos estructurados JSON-LD (`schema.org/MobileApplication`) con nombre, categoría, `downloadUrl` directo al APK, imagen y autor (`Kinetiqsystem`).
- `robots.txt` (permite todo, referencia el sitemap) y `sitemap.xml` (las dos páginas, `lastmod` 2026-09-23).

**Limitación conocida:** la imagen usada en Open Graph es `assets/logo.png`, cuadrada (246×246). Facebook/WhatsApp/etc. prefieren 1200×630 para la vista previa al compartir — no rompe nada, solo se ve recortada/pequeña. Mejora cosmética pendiente, no urgente.

**Pendiente (pedido explícitamente por el usuario, para una sesión futura):** verificar la propiedad del dominio en Google Search Console y enviar `sitemap.xml` ahí. Los métodos típicos que va a pedir Search Console:
- Subir un archivo HTML de verificación a la raíz de `website/` (y republicar con `git subtree push`, ver abajo), o
- Agregar un registro TXT en el DNS de `jotaelebundle.com` en IONOS.

## Publicación: repo propio + GitHub Pages + dominio de IONOS

Ver la sección "Website" en [05-deployment.md](05-deployment.md) para el paso a paso completo de cómo se publica (repo `webjotaelebundle`, `git subtree push`, configuración de GitHub Pages, y los registros DNS en IONOS) y el porqué de elegir GitHub Pages sobre EasyPanel en [06-decisions.md](06-decisions.md).
