/* campaign-loader.js
   — Linha única fixa no index.html:
   <script defer src="assets/js/campaign-loader.js"></script>
   — Ele procura: assets/campaigns/active.json
   — Se não existir ou estiver disabled, não faz nada (silencioso).
*/

(function () {
  'use strict';

  // Caminhos relativos ao index.html na raiz
  const ACTIVE_JSON_URL = 'assets/campaigns/active.json';
  const MODAL_SCRIPT_URL = 'assets/js/campaign-modal.js';

  function ready(fn) {
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', fn);
    } else {
      fn();
    }
  }

  async function getActiveCampaign() {
    try {
      const res = await fetch(ACTIVE_JSON_URL, { cache: 'no-store' });
      if (!res.ok) return null; // 404 ou outro -> sem campanha
      const data = await res.json();
      if (!data || data.enabled === false) return null;
      return data;
    } catch {
      return null; // falha de rede etc. -> silencioso
    }
  }

  function loadScript(src) {
    return new Promise((resolve, reject) => {
      const s = document.createElement('script');
      s.src = src;
      s.defer = true;
      s.onload = resolve;
      s.onerror = reject;
      document.head.appendChild(s);
    });
  }

  ready(async function () {
    const cfg = await getActiveCampaign();
    if (!cfg) return; // sem campanha -> não faz nada

    // Por enquanto suportamos type: "modal"
    if (cfg.type === 'modal') {
      try {
        await loadScript(MODAL_SCRIPT_URL);
        if (window.CampaignModal && typeof window.CampaignModal.show === 'function') {
          window.CampaignModal.show(cfg);
        }
      } catch {
        // erro ao carregar o renderer -> silencioso
      }
    }
    // Futuro: outros tipos (banner/topbar) podem ser tratados aqui
  });
})();