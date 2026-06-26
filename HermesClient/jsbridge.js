// Custom JS bridge injected into the WebView
// This enables HermesClient native features to communicate with the WebUI

(function() {
    'use strict';
    
    // Don't inject twice
    if (window.__hermesClientBridge) return;
    window.__hermesClientBridge = true;
    
    // === Pet Rendering ===
    // Overlay native pet canvas (the WebView handles this via injected HTML)
    function injectPetRenderer() {
        const container = document.createElement('div');
        container.id = 'hermes-client-pet';
        container.style.cssText = 'position:fixed;bottom:60px;left:16px;z-index:9999;pointer-events:none;';
        document.body.appendChild(container);
    }
    
    // === Skin Sync ===
    // Listen for skin changes from the native app
    window.addEventListener('message', function(event) {
        if (event.data?.type === 'hermes:set-skin') {
            document.documentElement.dataset.skin = event.data.skin;
            localStorage.setItem('hermes-skin', event.data.skin);
        }
        if (event.data?.type === 'hermes:set-font-size') {
            document.documentElement.dataset.fontSize = event.data.size;
            localStorage.setItem('hermes-webui-font-size', event.data.size);
        }
    });
    
    // === Pipeline Quick Status ===
    // Expose a function the native app can call via evaluateJavaScript
    window.__hermesPipeline = {
        status: function() {
            return JSON.stringify({
                lastScan: localStorage.getItem('pipeline_last_scan') || 'never',
                confirmed: localStorage.getItem('pipeline_confirmed') || '0',
                pending: localStorage.getItem('pipeline_pending') || '0'
            });
        }
    };
    
    // === Activity Detection ===
    // Notify native layer when agent is processing
    let lastActivity = Date.now();
    const observer = new MutationObserver(function() {
        const isRunning = !!document.querySelector('.tool-card-running');
        if (isRunning) {
            lastActivity = Date.now();
            window.webkit?.messageHandlers?.hermesActivity?.postMessage({type: 'agent-running'});
        }
    });
    
    setTimeout(function() {
        const chatArea = document.querySelector('.messages-container') || document.body;
        observer.observe(chatArea, { childList: true, subtree: true });
    }, 2000);
    
    // === Auto Dark Mode ===
    function applyDarkMode() {
        const isDark = document.documentElement.dataset.theme === 'dark' ||
                      window.matchMedia('(prefers-color-scheme: dark)').matches;
        if (isDark) {
            document.body.classList.add('dark');
        }
    }
    applyDarkMode();
    
    console.log('[HermesClient] Bridge loaded');
})();
