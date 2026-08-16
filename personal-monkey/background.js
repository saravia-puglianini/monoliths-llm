chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
    if (request.action === 'fetch') {
        const { url, options } = request;
        fetch(url, options)
            .then(async res => {
                const text = await res.text();
                sendResponse({
                    success: true,
                    data: {
                        status: res.status,
                        ok: res.ok,
                        text: text
                    }
                });
            })
            .catch(err => {
                sendResponse({
                    success: false,
                    error: err.message || err.toString()
                });
            });
        return true; // Indicates asynchronous response
    }
});
