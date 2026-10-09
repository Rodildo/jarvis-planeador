# 08 — Website

Ubicación: `website/` (dentro del repo principal). HTML/CSS/JS puro, sin build, sin dependencias ni framework. Desde el 9 de octubre de 2026 es el sitio de **Total System** (marca de servicios de software del usuario): home con los servicios, más una página propia para cada app (ChattFlow y Jarvis Planeador) y las políticas de privacidad.

```
website/
  index.html                 — home: hero, 8 servicios, apps, proceso, FAQ y contacto
  chattflow.html             — página de ChattFlow (APK, funciones, planes, cómo funciona)
  jarvis-planeador.html      — página de Jarvis Planeador (APK, capturas, cómo funciona)
  privacidad.html            — Privacidad y Términos de Jarvis (mismo texto que /legal dentro de la app)
  chatflow-privacidad.html   — Privacidad y Términos de ChattFlow (borrador, con campos [pendiente])
  404.html                   — error con la marca, rutas absolutas (/css/...) porque se sirve desde cualquier ruta
  css/total.css              — única hoja de estilos: tokens de marca en :root + todos los componentes
  js/site.js                 — menú móvil (la página funciona completa sin JS)
  fonts/                     — Outfit y Manrope autohospedadas (woff2, subset latin)
  assets/
    servicios/               — los 8 flyers de la marca, recortados sin la barra de contacto, en dos tamaños (-480.jpg y completo)
    screenshots/             — capturas reales de Jarvis (blueprint.jpg, daily-plan.jpg)
    og-total-system.png      — imagen 1200×630 para compartir el link
    favicon-48.png, apple-touch-icon.png, logo-total-system-512.png
    logo.png                 — ícono de Jarvis (246×246), usado en el JSON-LD de su página
  robots.txt, sitemap.xml, CNAME (www.jotaelebundle.com), Dockerfile, .dockerignore
  PRODUCT.md                 — contexto de producto para el skill de diseño (no es parte del sitio)
```

## Contenido de las páginas

- **`index.html`**: hero ("Tu negocio completo en un solo sistema") con un abanico de tres flyers; los 8 servicios tomados de los flyers (chatbot de WhatsApp, facturación electrónica SENIAT, MedicPro, AcademiaPro, restaurantes, gimnasios, préstamos y cobranza, software a medida); las dos apps; cómo empezar (4 pasos); FAQ de 8 preguntas; barra magenta de cierre. Cada servicio es texto indexable con su flyer como imagen (con `alt` descriptivo) y un botón de contacto con asunto prellenado.
- **`chattflow.html`** y **`jarvis-planeador.html`**: el contenido que antes vivía en secciones de la home (funciones, pasos, precios de ChattFlow: Básico "precio a confirmar" y Pro $35/mes; capturas y pasos de Jarvis), ahora cada una en su URL con título, descripción y datos estructurados propios.
- **`privacidad.html`** y **`chatflow-privacidad.html`**: el texto legal no se tocó, solo el diseño y el correo de contacto. El de Jarvis sigue mantenido a mano en paralelo con `frontend/lib/legal_screen.dart`; ahora los dos tienen correos distintos (la app aún dice el anterior).
- Botones de descarga: `https://github.com/Rodildo/jarvis-planeador/releases/latest/download/jarvis-planeador.apk` y `https://github.com/Rodildo/whatsapp-manager-bot-apk/releases/latest/download/chattflow.apk`. Esas URLs siempre sirven el asset con ese nombre del release más reciente, así que no hay que tocar el HTML al publicar una build nueva (ver [PROYECTO.md](../../PROYECTO.md), regla 4).

## Contacto: solo correo, por ahora

Por orden del usuario (9 de octubre de 2026), **todo contacto del sitio va a `jorgecastilloowner@jotaelebundle.com`**: cada botón es un `mailto:` con asunto y mensaje prellenados según el servicio, y el correo aparece en el pie, el FAQ y el JSON-LD (`contactPoint`). No hay número de WhatsApp en el sitio. Los flyers originales traen impreso el WhatsApp `+58 422 330 0722` y `www.totalsystem.com` en su barra inferior, así que las copias de `assets/servicios/` están **recortadas justo encima de esa barra** (los originales completos no están en el repo). Para volver a WhatsApp habría que usar los flyers originales y cambiar los `mailto:` por `https://wa.me/584223300722`. Para cambiar el correo: buscar y reemplazar en los `.html`.

## Diseño

Tomado de los flyers de Total System: fondo negro-ciruela (`--ink`), magenta (`--pink`), coral (`--coral`) y una variante crema (`--cream`); las secciones alternan oscuro y crema y el cierre es una barra magenta con una píldora blanca de contacto, como en los flyers. Tipografías Outfit (títulos) y Manrope (texto) autohospedadas. Sin librerías: el único movimiento es la entrada del abanico de flyers y un asentado de cada flyer al hacer scroll (`animation-timeline: view()`, solo donde el navegador lo soporta). Respeta `prefers-reduced-motion`. Contraste AA (el magenta de los botones es `#dc1672` y su hover `#c4105f` para que el texto blanco cumpla 4.5:1).

## SEO

En todas las páginas: `<title>` (≤ 60 caracteres) y descripción (≤ 160) únicos, `canonical`, `robots` con `max-image-preview:large`, `lang="es"`, `theme-color`, Open Graph y Twitter Card `summary_large_image` con `assets/og-total-system.png` (1200×630), un solo `<h1>`, jerarquía h2/h3.

Datos estructurados JSON-LD:
- `index.html`: `Organization` (nombre Total System, logo, `contactPoint` con el correo, `OfferCatalog` con los 8 servicios), `WebSite` y `FAQPage`. El texto del FAQ del JSON-LD es idéntico al visible.
- `chattflow.html` y `jarvis-planeador.html`: `MobileApplication` (con `downloadUrl` al APK, y `offers`: ChattFlow Pro 35 USD, Jarvis gratis) y `BreadcrumbList`. El `publisher` es Total System.

Rendimiento y rastreo: fuentes autohospedadas con `preload`, imagen principal con `preload` y `fetchpriority`, `width`/`height` en todas las imágenes, `srcset` con versión de 480 px, `loading="lazy"` bajo el primer pantallazo, `sitemap.xml` con las 5 páginas (`lastmod` 2026-10-09), `robots.txt` apuntando al sitemap, `404.html` con `noindex`. Accesibilidad: enlace para saltar al contenido, foco visible, menú móvil con `aria-expanded`.

**Dominio:** el sitio se sirve desde `www.jotaelebundle.com`; los flyers dicen `www.totalsystem.com`. Es una decisión abierta. Si se conecta ese dominio hay que cambiarlo en `CNAME`, `robots.txt`, `sitemap.xml`, y en los `canonical`, `og:url`, `og:image` y JSON-LD de los `.html` (buscar y reemplazar `https://www.jotaelebundle.com`).

**Pendiente (pedido explícitamente por el usuario, para una sesión futura):** verificar la propiedad del dominio en Google Search Console y enviar `sitemap.xml` ahí. Los métodos típicos que va a pedir:
- Subir un archivo HTML de verificación a la raíz de `website/` (y republicar con `git subtree push`, ver abajo), o
- Agregar un registro TXT en el DNS de `jotaelebundle.com` en IONOS.

## Publicación: repo propio + GitHub Pages + dominio de IONOS

Ver la sección "Website" en [05-deployment.md](05-deployment.md) para el paso a paso completo de cómo se publica (repo `webjotaelebundle`, `git subtree push`, configuración de GitHub Pages, y los registros DNS en IONOS) y el porqué de elegir GitHub Pages sobre EasyPanel en [06-decisions.md](06-decisions.md). Nota: GitHub Pages publica todo lo que haya en `website/`, incluidos `PRODUCT.md` y `README.md`; el `.dockerignore` solo los excluye de la imagen Docker.
