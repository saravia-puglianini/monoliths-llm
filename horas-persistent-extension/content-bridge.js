window.addEventListener('message', event => {
  if (event.source !== window || event.data?.type !== 'HORAS_EXTENSION_REQUEST') return;
  const { requestId, payload, requestType = 'HORAS_GET_TODAY_RECORDS' } = event.data;
  chrome.runtime.sendMessage({ type: requestType, payload }, response => {
    const result = chrome.runtime.lastError
      ? { ok: false, error: chrome.runtime.lastError.message }
      : response;
    window.postMessage({ type: 'HORAS_EXTENSION_RESPONSE', requestId, result }, window.location.origin);
  });
});
