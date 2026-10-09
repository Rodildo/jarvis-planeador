// Menú móvil: abre y cierra la lista de navegación, y la cierra al tocar un enlace
// o al pulsar Escape. Sin dependencias; la página funciona completa sin JS.
(function () {
  const toggle = document.querySelector('.nav-toggle');
  const menu = document.getElementById('menu');
  if (!toggle || !menu) return;

  function setOpen(open) {
    menu.classList.toggle('open', open);
    toggle.setAttribute('aria-expanded', String(open));
    toggle.setAttribute('aria-label', open ? 'Cerrar menú' : 'Abrir menú');
  }

  toggle.addEventListener('click', () => setOpen(!menu.classList.contains('open')));
  menu.addEventListener('click', (event) => {
    if (event.target.closest('a')) setOpen(false);
  });
  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && menu.classList.contains('open')) {
      setOpen(false);
      toggle.focus();
    }
  });
})();
