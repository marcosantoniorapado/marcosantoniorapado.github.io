/* campaign-modal.js
   Motor fixo para campanhas modais.
   Lê estilos e conteúdos direto do active.json.
*/
(function () {
  'use strict';

  const CampaignModal = {
    show(cfg) {
      const c = normalize(cfg);
      if (!canShow(c)) return;
      setupExitIntent(c);
      setTimeout(() => render(c), c.delayMs);
    }
  };
  window.CampaignModal = CampaignModal;

  // ---------- helpers ----------
  function normalize(o) {
    return {
      id: o.id || 'campaign',
      delayMs: Number(o.delayMs ?? 4000),
      showOnExitIntent: !!o.showOnExitIntent,
      blockReshowHours: Number(o.blockReshowHours ?? 24),
      headline: o.headline || '',
      headlineStyle: o.headlineStyle || {},
      dateLineHtml: o.dateLineHtml || '',
      bulletsHtml: Array.isArray(o.bulletsHtml) ? o.bulletsHtml : [],
      footerHtml: Array.isArray(o.footerHtml) ? o.footerHtml : [],
      cta: o.cta || null,
      secondaryCta: o.secondaryCta || null,
      theme: o.theme || {}
    };
  }

  function storageKey(id) { return `campaignDismissedAt:${id}`; }

  function canShow(c) {
    try {
      const ts = localStorage.getItem(storageKey(c.id));
      if (!ts) return true;
      const last = parseInt(ts, 10);
      if (Number.isNaN(last)) return true;
      const hours = (Date.now() - last) / (1000 * 60 * 60);
      return hours >= c.blockReshowHours;
    } catch { return true; }
  }

  function markDismissed(id) {
    try { localStorage.setItem(storageKey(id), String(Date.now())); } catch {}
  }

  function setupExitIntent(c) {
    if (!c.showOnExitIntent) return;
    let armed = true;
    document.addEventListener('mousemove', (e) => {
      if (!armed) return;
      if (e.clientY <= 8) { render(c); armed = false; }
    });
  }

  function applyStyles(el, styles) {
    if (!styles) return;
    Object.keys(styles).forEach(k => {
      el.style[k] = styles[k];
    });
  }

  function render(c) {
    if (document.getElementById(`modal-${c.id}`)) return;

    const { theme } = c;

    // overlay
    const overlayEl = document.createElement('div');
    overlayEl.id = `modal-${c.id}`;
    Object.assign(overlayEl.style, {
      position: 'fixed',
      inset: '0',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      background: theme.overlay || 'rgba(0,0,0,0.6)',
      zIndex: 9999,
      padding: '16px',
      opacity: 0,
      transition: 'opacity 160ms ease'
    });

    // card
    const card = document.createElement('div');
    Object.assign(card.style, {
      width: '100%',
      maxWidth: theme.maxWidth || '560px',
      background: theme.bg || '#fff',
      color: theme.text || '#000',
      borderRadius: theme.borderRadius || '16px',
      boxShadow: theme.boxShadow || '0 10px 30px rgba(0,0,0,0.15)',
      border: theme.border || '1px solid #e2e8f0',
      padding: '22px',
      fontFamily: theme.fontFamily || 'inherit',
      position: 'relative'
    });

    // close
    const closeBtn = document.createElement('button');
    closeBtn.setAttribute('aria-label', 'Fechar');
    closeBtn.innerHTML = '✕';
    Object.assign(closeBtn.style, {
      position: 'absolute',
      top: '10px',
      right: '12px',
      border: 'none',
      background: '#fff',
      padding: '4px 8px',
      borderRadius: '8px',
      cursor: 'pointer'
    });

    // headline
    const h1 = document.createElement('div');
    h1.innerHTML = c.headline;
    applyStyles(h1, { fontWeight: '700', fontSize: '20px', marginBottom: '8px' });
    applyStyles(h1, c.headlineStyle);

    // date line
    const dl = document.createElement('div');
    dl.innerHTML = c.dateLineHtml;
    applyStyles(dl, { fontSize: '15px', marginBottom: '12px' });

    // bullets
    const ul = document.createElement('ul');
    applyStyles(ul, { paddingLeft: '18px', margin: '0 0 10px 0' });
    c.bulletsHtml.forEach(html => {
      const li = document.createElement('li');
      li.innerHTML = html;
      ul.appendChild(li);
    });

    // footer
    const footer = document.createElement('div');
    footer.innerHTML = c.footerHtml.map(x => `<div>${x}</div>`).join('');
    applyStyles(footer, { fontSize: '14px', margin: '10px 0 14px 0' });

    // botões
    const ctas = document.createElement('div');
    Object.assign(ctas.style, { display: 'flex', justifyContent: 'center', marginTop: '16px' });

    function buildBtn(btnCfg) {
      const a = document.createElement('a');
      a.href = btnCfg.href;
      a.textContent = btnCfg.text;
      applyStyles(a, {
        display: 'inline-block',
        padding: '12px 20px',
        borderRadius: '25px',
        background: theme.brand || '#2563eb',
        color: '#fff',
        textDecoration: 'none',
        fontWeight: '600',
        textAlign: 'center',
        minWidth: '200px'
      });
      if (btnCfg.style) applyStyles(a, btnCfg.style);
      return a;
    }

    if (c.cta) ctas.appendChild(buildBtn(c.cta));
    if (c.secondaryCta) ctas.appendChild(buildBtn(c.secondaryCta));

    // dismiss
    function dismiss() {
      markDismissed(c.id);
      overlayEl.style.opacity = '0';
      setTimeout(() => overlayEl.remove(), 180);
    }
    overlayEl.addEventListener('click', (e) => { if (e.target === overlayEl) dismiss(); });
    closeBtn.addEventListener('click', dismiss);

    // montagem
    card.appendChild(closeBtn);
    card.appendChild(h1);
    if (c.dateLineHtml) card.appendChild(dl);
    if (c.bulletsHtml.length) card.appendChild(ul);
    card.appendChild(footer);
    card.appendChild(ctas);

    overlayEl.appendChild(card);
    document.body.appendChild(overlayEl);
    requestAnimationFrame(() => overlayEl.style.opacity = '1');
  }
})();