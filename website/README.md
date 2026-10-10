# Sitio web de Total System

Sitio estático (HTML + CSS + un poco de JS, sin build ni dependencias) de **Total System**: servicios de software (chatbot de WhatsApp, facturación electrónica, sistemas por industria, software a medida) y las dos apps Android, ChattFlow y Jarvis Planeador.

```
website/
  index.html                 — home: hero, los 9 servicios de los flyers, bloque que lleva al catálogo, apps, proceso, FAQ y contacto
  sistemas.html              — catálogo: más de 30 sistemas en 9 categorías; cada uno abre un correo prellenado
  chattflow.html             — página propia de ChattFlow (APK, planes, cómo funciona)
  jarvis-planeador.html      — página propia de Jarvis Planeador (APK, capturas, cómo funciona)
  privacidad.html            — Privacidad y Términos de Jarvis Planeador
  chatflow-privacidad.html   — Privacidad y Términos de ChattFlow (borrador, tiene campos [pendiente])
  404.html                   — página de error con la marca (GitHub Pages la sirve sola)
  css/total.css              — única hoja de estilos: tokens de marca + todos los componentes
  js/site.js                 — menú móvil (la página funciona completa sin JS)
  fonts/                     — Outfit y Manrope autohospedadas (woff2, subset latin)
  assets/
    servicios/               — los flyers de la marca, sin la barra de contacto (ver abajo); cada uno en 2 tamaños (-480.jpg y completo)
    screenshots/             — capturas reales de Jarvis Planeador
    og-total-system.png      — imagen 1200x630 para compartir el link
    favicon-48.png, apple-touch-icon.png, logo-total-system-512.png, logo.png (ícono de Jarvis)
  CNAME, robots.txt, sitemap.xml, Dockerfile, .dockerignore
  PRODUCT.md                 — contexto de producto para el skill de diseño (no es parte del sitio)
```

## Diseño

Tomado de los flyers de Total System: fondo negro-ciruela (`--ink`), magenta (`--pink`), coral (`--coral`) y una variante crema (`--cream`), con la barra magenta de cierre. Los tokens están al inicio de `css/total.css`. Tipografías: Outfit (títulos) y Manrope (texto), servidas desde `fonts/`. Las secciones alternan oscuro y crema.

## Contacto (por ahora, solo correo)

Todos los botones de contacto son enlaces `mailto:` a **jorgecastilloowner@jotaelebundle.com**, con asunto y mensaje prellenados según el servicio. Es una decisión temporal: los flyers traen impreso el WhatsApp +58 422 330 0722 y el sitio www.totalsystem.com en su barra inferior, así que **las imágenes de `assets/servicios/` están recortadas justo encima de esa barra** para no mostrar un contacto que hoy no es el oficial. Los originales completos no están en el repo; para volver a WhatsApp hay que usar los flyers originales y cambiar los `mailto:` por `https://wa.me/584223300722`.

Para cambiar el correo: buscar y reemplazar `jorgecastilloowner@jotaelebundle.com` en todos los `.html` (también aparece en el JSON-LD de `index.html`).

## Activar los botones de descarga

Las páginas enlazan a dos APK en GitHub Releases: `chattflow.apk` (repo `Rodildo/whatsapp-manager-bot-apk`) y `jarvis-planeador.apk` (repo `Rodildo/jarvis-planeador`). El botón "Descargar APK" de Jarvis apunta a:
```
https://github.com/Rodildo/jarvis-planeador/releases/latest/download/jarvis-planeador.apk
```

Esa URL de GitHub **siempre sirve el asset con ese nombre exacto del release más reciente** — no hay que tocar el HTML nunca más una vez configurado. Para activarlo:

1. Compila el APK desde Android Studio (como siempre, nunca en segundo plano — ver `AGENTS.md`).
2. En GitHub, ve a `Releases` → `Draft a new release`.
3. Sube el `.apk` compilado y renómbralo (o el asset) exactamente a `jarvis-planeador.apk`.
4. Publica el release.

Cada vez que saques una versión nueva, solo repite los pasos 1-4 con un release nuevo — el link de la landing no cambia.

**Alternativa** si no quieres usar GitHub Releases: sube el `.apk` a `website/assets/jarvis-planeador.apk` y cambia el `href` de los botones de descarga en `jarvis-planeador.html` e `index.html` a `assets/jarvis-planeador.apk`. Más simple, pero el archivo queda versionado en git (pesa varias decenas de MB) y hay que reemplazarlo a mano en cada release.

## Publicar el sitio

Es HTML/CSS estático puro — no necesita build ni servidor con lógica.

**Decisión tomada (22 de septiembre de 2026):** esta carpeta se publica en su propio repo, [`Rodildo/webjotaelebundle`](https://github.com/Rodildo/webjotaelebundle), extraído de aquí con `git subtree push --prefix=website website-repo main` (el remote `website-repo` ya queda configurado en el repo principal, apunta a esa URL). Cada vez que se edite algo en `website/`, se vuelve a correr ese mismo comando para republicar — no hace falta recordar la sintaxis exacta, basta con pedir "sube la página web" otra vez.

**Decisión revisada (23 de septiembre de 2026):** en vez de EasyPanel, el sitio se publica con **GitHub Pages** sobre ese mismo repo `webjotaelebundle`, con el dominio propio `www.jotaelebundle.com` (comprado en IONOS) apuntando ahí. Pasos ya dados y pendientes:

1. Archivo `CNAME` en la raíz de `website/` con el contenido `www.jotaelebundle.com` — ya está, se publica junto con el resto del sitio en cada `git subtree push`.
2. En GitHub, dentro de `Rodildo/webjotaelebundle` → `Settings` → `Pages`: `Source` = `Deploy from a branch`, rama `main`, carpeta `/ (root)`. Guardar.
3. En el mismo panel de `Pages`, en `Custom domain` debe aparecer (o escribirse) `www.jotaelebundle.com` y guardarse — GitHub verifica el DNS automáticamente una vez esté configurado (paso 4).
4. En IONOS, en la gestión DNS de `jotaelebundle.com`, agregar un registro:
   - Tipo `CNAME`, host/nombre `www`, valor `rodildo.github.io.` (con el punto final si IONOS lo pide, o `rodildo.github.io` si no lo acepta).
   - La propagación puede tardar de minutos a un par de horas.
5. Una vez GitHub detecta el DNS válido, activar `Enforce HTTPS` en el mismo panel de `Pages` (tarda un poco en aparecer disponible tras verificar el dominio).
6. Opcional: quien escriba `jotaelebundle.com` sin `www` no llega al sitio a menos que se configure aparte (un dominio raíz no puede usar CNAME por spec de DNS). Si se quiere cubrir ese caso, IONOS suele tener una opción de "redirección/forwarding" de dominio para mandar `jotaelebundle.com` → `https://www.jotaelebundle.com`, configurable desde su panel sin tocar este repo.

EasyPanel ya no hace falta para este sitio — el static site en EasyPanel documentado arriba queda descartado a favor de GitHub Pages.

## SEO

Hecho en el HTML de cada página:

- `<title>` (≤ 60 caracteres) y `<meta name="description">` (≤ 160) únicos, con las palabras clave del servicio.
- `<link rel="canonical">`, `robots` con `max-image-preview:large`, `lang="es"`, `theme-color`.
- Open Graph y Twitter Card (`summary_large_image`) con `assets/og-total-system.png` (1200x630).
- Datos estructurados JSON-LD: `Organization` (con `OfferCatalog` de los servicios principales y del catálogo), `WebSite` y `FAQPage` en `index.html`; `MobileApplication` y `BreadcrumbList` en cada página de app; `CollectionPage` + `ItemList` (36 entradas) y `BreadcrumbList` en `sistemas.html`. El texto del FAQ del JSON-LD es idéntico al visible.
- Un solo `<h1>` por página, jerarquía h2/h3 correcta, cada servicio es texto indexable (no solo imagen), `alt` descriptivo en cada flyer, `width`/`height` en todas las imágenes (sin saltos de layout), `loading="lazy"` bajo el primer pantallazo, `srcset` con versión de 480 px, precarga de fuentes y de la imagen principal.
- `sitemap.xml` con las 6 páginas, `robots.txt` apuntando a él, `404.html` con `noindex`.
- Accesibilidad: enlace para saltar al contenido, foco visible, contraste AA, `prefers-reduced-motion`, menú móvil con `aria-expanded`.

**Dominio:** el sitio se sirve desde `www.jotaelebundle.com` (CNAME). Los flyers dicen `www.totalsystem.com`; si se conecta ese dominio hay que cambiarlo en `CNAME`, `robots.txt`, `sitemap.xml`, y en los `canonical`, `og:url`, `og:image` y JSON-LD de los `.html` (buscar y reemplazar `https://www.jotaelebundle.com`).

**Pendiente (a petición del usuario, para una sesión futura):** verificar la propiedad del dominio en **Google Search Console** y enviar el `sitemap.xml` ahí para que Google empiece a indexar el sitio. Suele pedir uno de estos dos métodos:
- Subir un archivo HTML de verificación a la raíz del sitio (a `website/`, y volver a publicar con `git subtree push`), o
- Agregar un registro TXT en el DNS de `jotaelebundle.com` en IONOS.

## Capturas de pantalla

Las capturas actuales (`assets/screenshots/`) son reales, tomadas del dispositivo del usuario. Si la UI de esas pantallas cambia en el futuro, hay que volver a tomarlas y reemplazar esos dos archivos (mismo nombre, mismas proporciones ~763×1600 funciona bien con el marco de teléfono en CSS).
