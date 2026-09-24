# Sitio web de Jarvis Planeador

Landing page estática (HTML + CSS puro, sin build ni dependencias) para descargar el APK de Jarvis Planeador.

```
website/
  index.html          — landing principal
  privacidad.html      — Política de Privacidad y Términos (mismo texto que /legal dentro de la app)
  css/styles.css
  CNAME                — dominio personalizado para GitHub Pages (www.jotaelebundle.com)
  robots.txt           — permite indexar todo, apunta al sitemap
  sitemap.xml           — las dos páginas del sitio, para Google Search Console
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

Lo básico ya está puesto en `index.html` y `privacidad.html`:

- `<link rel="canonical">` y `<meta name="robots" content="index, follow">` en ambas páginas.
- Open Graph + Twitter Card (título, descripción, imagen) para que se vea bien al compartir el link.
- Datos estructurados JSON-LD (`schema.org/MobileApplication`) en `index.html`, con nombre, categoría, `downloadUrl` al APK y autor.
- `robots.txt` (permite todo, apunta al sitemap) y `sitemap.xml` con las dos URLs del sitio.

**Pendiente (a petición del usuario, para una sesión futura):** verificar la propiedad del dominio en **Google Search Console** y enviar el `sitemap.xml` ahí para que Google empiece a indexar el sitio. Suele pedir uno de estos dos métodos:
- Subir un archivo HTML de verificación a la raíz del sitio (a `website/`, y volver a publicar con `git subtree push`), o
- Agregar un registro TXT en el DNS de `jotaelebundle.com` en IONOS.

Si más adelante se quiere mejorar el posicionamiento todavía más: la imagen usada en Open Graph (`assets/logo.png`, 246×246) es cuadrada — redes como Facebook/WhatsApp prefieren una imagen 1200×630 para la vista previa al compartir el link; no es bloqueante, solo una mejora cosmética futura.

## Capturas de pantalla

Las capturas actuales (`assets/screenshots/`) son reales, tomadas del dispositivo del usuario. Si la UI de esas pantallas cambia en el futuro, hay que volver a tomarlas y reemplazar esos dos archivos (mismo nombre, mismas proporciones ~763×1600 funciona bien con el marco de teléfono en CSS).
