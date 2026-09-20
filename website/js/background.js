// Campo de estrellas titilando, generado una sola vez al cargar. Nada de
// dependencias: son <span> posicionados al azar con una animación CSS de
// opacidad. Respeta prefers-reduced-motion (ver css/styles.css) y se
// desactiva solo si el usuario lo tiene activado a nivel de sistema.
(function () {
  const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  if (prefersReducedMotion) return;

  const container = document.getElementById('stars');
  if (!container) return;

  const STAR_COUNT = 70;
  const fragment = document.createDocumentFragment();

  for (let i = 0; i < STAR_COUNT; i++) {
    const star = document.createElement('span');
    star.className = 'star';
    const size = (Math.random() * 1.6 + 0.6).toFixed(2);
    star.style.left = Math.random() * 100 + '%';
    star.style.top = Math.random() * 100 + '%';
    star.style.width = size + 'px';
    star.style.height = size + 'px';
    star.style.animationDelay = (Math.random() * 6).toFixed(2) + 's';
    star.style.animationDuration = (3 + Math.random() * 4).toFixed(2) + 's';
    fragment.appendChild(star);
  }

  container.appendChild(fragment);
})();
