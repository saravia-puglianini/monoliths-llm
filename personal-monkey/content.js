(function() {
  function injectScript() {
    const script = document.createElement('script');
    script.src = chrome.runtime.getURL('personal-script.js?t=' + Date.now());
    script.onload = function() {
      this.remove();
    };
    script.onerror = function(err) {
      console.error('[Personal Monkey] Error loading personal-script.js:', err);
    };
    (document.head || document.documentElement).appendChild(script);
  }

  // Ejecutar inmediatamente al cargar la página
  injectScript();

  // Y luego cada 5 segundos
  setInterval(injectScript, 5000);
})();
