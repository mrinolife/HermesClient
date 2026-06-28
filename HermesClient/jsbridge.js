// Custom JS bridge injected into the WebView
// This enables HermesClient native features to communicate with the WebUI

(function() {
    'use strict';
    
    // Don't inject twice
    if (window.__hermesClientBridge) return;
    window.__hermesClientBridge = true;
    
    // === Voice Response Detection ===
    // Monitors the chat for new assistant messages and sends them to native TTS
    let lastResponseCount = 0;
    let responseTimer = null;
    
    function watchForResponse() {
        // Find all assistant message elements
        const assistantMsgs = document.querySelectorAll(
            '[data-role="assistant"] .msg-body, ' +
            '.message.assistant .content, ' +
            '.msg-row[data-role="assistant"] .msg-text, ' +
            '.assistant-message .text'
        );
        
        if (assistantMsgs.length > lastResponseCount && assistantMsgs.length > 0) {
            // New response detected
            const latest = assistantMsgs[assistantMsgs.length - 1];
            const text = latest.textContent || latest.innerText || '';
            
            if (text.trim()) {
                // Debounce: wait for streaming to settle (500ms of no new text)
                if (responseTimer) clearTimeout(responseTimer);
                responseTimer = setTimeout(function() {
                    try {
                        window.webkit.messageHandlers.hermesResponse.postMessage({
                            type: 'assistant_response',
                            text: text.trim()
                        });
                    } catch(e) {
                        // WebKit bridge not available (non-iOS)
                    }
                    lastResponseCount = assistantMsgs.length;
                }, 500);
            }
        }
        lastResponseCount = Math.max(lastResponseCount, assistantMsgs.length);
    }
    
    // Observe DOM changes to catch new messages
    const observer = new MutationObserver(function(mutations) {
        for (const mutation of mutations) {
            if (mutation.addedNodes.length > 0) {
                watchForResponse();
                break;
            }
        }
    });
    
    // Start observing once the chat area exists
    function startObserving() {
        const chatArea = document.querySelector(
            '.messages-container, ' +
            '.chat-messages, ' +
            '#messages, ' +
            '[class*="messages"], ' +
            'main'
        ) || document.body;
        
        observer.observe(chatArea, {
            childList: true,
            subtree: true
        });
    }
    
    // Try immediately and again after load
    startObserving();
    setTimeout(startObserving, 2000);
    
    // === Pet Rendering ===
    function injectPetRenderer() {
        const container = document.createElement('div');
        container.id = 'hermes-client-pet';
        container.style.cssText = 'position:fixed;bottom:60px;left:16px;z-index:9999;pointer-events:none;';
        document.body.appendChild(container);
    }
    
    // === Skin Sync ===
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
    window.__hermesPipeline = {
        status: function() {
            return JSON.stringify({
                lastScan: localStorage.getItem('pipeline_last_scan') || 'never',
                confirmed: localStorage.getItem('pipeline_confirmed') || '0',
                pending: localStorage.getItem('pipeline_pending') || '0'
            });
        }
    };
    
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
