const toTop = document.getElementById('toTop');
const menuToggle = document.getElementById('menuToggle');
const mainMenu = document.getElementById('mainMenu');
const mobileMenuQuery = window.matchMedia('(max-width: 759px)');

window.addEventListener('scroll', () => {
  if (window.scrollY > 420) {
    toTop.classList.add('show');
  } else {
    toTop.classList.remove('show');
  }
});

if (menuToggle && mainMenu) {
  const setMenuState = (isOpen) => {
    mainMenu.classList.toggle('is-open', isOpen);
    menuToggle.setAttribute('aria-expanded', String(isOpen));
    menuToggle.setAttribute('aria-label', isOpen ? 'Fechar menu' : 'Abrir menu');
  };

  const syncMenuForViewport = () => {
    if (mobileMenuQuery.matches) {
      setMenuState(false);
      return;
    }

    mainMenu.classList.remove('is-open');
    menuToggle.setAttribute('aria-expanded', 'false');
    menuToggle.setAttribute('aria-label', 'Abrir menu');
  };

  menuToggle.addEventListener('click', () => {
    const isOpen = menuToggle.getAttribute('aria-expanded') === 'true';
    setMenuState(!isOpen);
  });

  mainMenu.querySelectorAll('a').forEach((link) => {
    link.addEventListener('click', () => {
      if (mobileMenuQuery.matches) {
        setMenuState(false);
      }
    });
  });

  mobileMenuQuery.addEventListener('change', syncMenuForViewport);
  syncMenuForViewport();
}
