(function() {
  let intervalId = null;

  function injectScript() {
    try {
      if (!chrome.runtime || !chrome.runtime.id) {
        if (intervalId) clearInterval(intervalId);
        return;
      }
      const script = document.createElement('script');
      script.src = chrome.runtime.getURL('personal-script.js?t=' + Date.now());
      script.onload = function() {
        this.remove();
      };
      script.onerror = function(err) {
        console.error('[Personal Monkey] Error loading personal-script.js:', err);
      };
      (document.head || document.documentElement).appendChild(script);
    } catch (e) {
      if (intervalId) clearInterval(intervalId);
    }
  }

  // Ejecutar inmediatamente al cargar la página
  injectScript();

  // Y luego cada 5 segundos
  intervalId = setInterval(injectScript, 5000);

  // Escuchar mensajes de la página para el background
  window.addEventListener('message', (event) => {
    if (event.source !== window) return;

    if (event.data && event.data.type === 'FROM_PAGE_FETCH') {
      chrome.runtime.sendMessage({
        action: 'fetch',
        url: event.data.url,
        options: event.data.options
      }, (response) => {
        window.postMessage({
          type: 'FROM_CONTENT_FETCH_RESPONSE',
          id: event.data.id,
          response: response
        }, '*');
      });
    }
  });
})();
