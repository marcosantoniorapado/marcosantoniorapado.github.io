const toTop = document.getElementById('toTop');
    window.addEventListener('scroll', () => {
      if (window.scrollY > 420) {
        toTop.classList.add('show');
      } else {
        toTop.classList.remove('show');
      }
    });