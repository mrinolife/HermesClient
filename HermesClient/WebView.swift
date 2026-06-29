import SwiftUI
import WebKit
import Combine

struct WebView: UIViewRepresentable {
    @EnvironmentObject var appState: AppState
    let url: URL
    let onTitleChange: (String) -> Void
    let onLoadingChange: (Bool) -> Void
    let onURLChange: (URL) -> Void
    let onAssistantResponse: (String) -> Void
    
    @Binding var refreshTrigger: UUID
    @Binding var pendingVoiceInput: String?
    @Binding var isReconnecting: Bool
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        let ucc = WKUserContentController()
        ucc.add(context.coordinator, name: "hermesResponse")
        
        // Dark mode injection
        let darkJS = "document.documentElement.dataset.theme = '\(appState.isDarkMode ? "dark" : "light")';"
        ucc.addUserScript(WKUserScript(source: darkJS, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        
        // Session tracker — watches title changes
        let sessionJS = """
        window._hsTitle = document.title;
        const _hsObs = new MutationObserver(() => {
            const t = document.title;
            if (t && t !== window._hsTitle) { window._hsTitle = t;
                window.webkit.messageHandlers.hermesResponse.postMessage({type: 'session_title', title: t}); }
        });
        _hsObs.observe(document.head || document.documentElement, {childList: true, subtree: true, characterData: true});
        document.addEventListener('visibilitychange', () => {
            if (!document.hidden && document.title !== window._hsTitle) { window._hsTitle = document.title;
                window.webkit.messageHandlers.hermesResponse.postMessage({type: 'session_title', title: document.title}); }
        });
        """
        ucc.addUserScript(WKUserScript(source: sessionJS, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        
        config.userContentController = ucc
        
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = context.coordinator
        wv.uiDelegate = context.coordinator
        wv.allowsBackForwardNavigationGestures = true
        wv.scrollView.contentInsetAdjustmentBehavior = .always
        if #available(iOS 18.0, *) { wv.configuration.upgradeKnownHostsToHTTPS = false }
        
        wv.load(URLRequest(url: url))
        return wv
    }
    
    func updateUIView(_ wv: WKWebView, context: Context) {
        if refreshTrigger != context.coordinator.lastRefresh {
            context.coordinator.lastRefresh = refreshTrigger
            wv.reload()
        }
        
        // Voice input injection
        if let text = pendingVoiceInput {
            context.coordinator.lastPendingText = text
            let escaped = text.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\n", with: "\\n")
            let js = """
            (function(){
                const i = document.querySelector('textarea, [contenteditable="true"]');
                if(i){
                    const s = Object.getOwnPropertyDescriptor(window.HTMLTextAreaElement.prototype,'value').set;
                    s.call(i,'\(escaped)'); i.dispatchEvent(new Event('input',{bubbles:true}));
                    const b = document.querySelector('button[aria-label="Send"], button.send-btn');
                    if(b) setTimeout(()=>b.click(),100);
                    window.webkit.messageHandlers.hermesResponse.postMessage({type:'voice_sent',text:'\(escaped)'});
                }
            })();
            """
            wv.evaluateJavaScript(js) { _, err in if let err = err { print("Voice inj err: \(err)") } }
            DispatchQueue.main.async { self.pendingVoiceInput = nil }
        }
        
        wv.evaluateJavaScript("""
            document.documentElement.dataset.theme = '\(appState.isDarkMode ? "dark" : "light")';
        """, completionHandler: nil)
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        var parent: WebView
        var lastRefresh = UUID()
        var lastPendingText = ""
        
        private var reconnectTimer: Timer?
        private var currentURL: URL?
        
        init(_ p: WebView) {
            self.parent = p
        }
        
        // MARK: Navigation
        func webView(_ wv: WKWebView, didStartProvisionalNavigation n: WKNavigation!) { parent.onLoadingChange(true) }
        
        func webView(_ wv: WKWebView, didFinish n: WKNavigation!) {
            parent.onLoadingChange(false)
            stopReconnect()
            if let t = wv.title { parent.onTitleChange(t) }
        }
        
        func webView(_ wv: WKWebView, didFail n: WKNavigation!, withError e: Error) {
            parent.onLoadingChange(false); handleError(wv, error: e)
        }
        
        func webView(_ wv: WKWebView, didFailProvisionalNavigation n: WKNavigation!, withError e: Error) {
            parent.onLoadingChange(false); handleError(wv, error: e)
        }
        
        // MARK: Auth detection
        func webView(_ wv: WKWebView, decidePolicyFor r: WKNavigationResponse, decisionHandler h: @escaping (WKNavigationResponsePolicy) -> Void) {
            if let resp = r.response as? HTTPURLResponse, resp.statusCode == 401 {
                DispatchQueue.main.async { [self] in
                    parent.onTitleChange("Login Required")
                    parent.onLoadingChange(false)
                }
            }
            h(.allow)
        }
        
        // MARK: JS messages
        func userContentController(_: WKUserContentController, didReceive msg: WKScriptMessage) {
            guard let body = msg.body as? [String: Any], let type = body["type"] as? String else { return }
            
            if type == "assistant_response", let text = body["text"] as? String { parent.onAssistantResponse(text) }
            
            if type == "session_title", let title = body["title"] as? String {
                let session = CachedSession(id: UUID().uuidString, title: title, lastMessage: nil, timestamp: Date())
                Task { @MainActor in parent.appState.cacheSession(session) }
            }
        }
        
        // MARK: Error handling
        private func handleError(_ wv: WKWebView, error: Error) {
            let ns = error as NSError
            if ns.code == NSURLErrorCancelled { return }
            
            // Save URL for reconnect
            if currentURL == nil { currentURL = wv.url }
            
            Task { @MainActor in
                parent.isReconnecting = true
            }
            startReconnect(wv)
        }
        
        private func startReconnect(_ wv: WKWebView) {
            reconnectTimer?.invalidate()
            reconnectTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    guard let url = self.currentURL else { return }
                    wv.load(URLRequest(url: url))
                }
            }
        }
        
        private func stopReconnect() {
            reconnectTimer?.invalidate()
            reconnectTimer = nil
            Task { @MainActor in
                parent.isReconnecting = false
            }
        }
        
        // MARK: New window
        func webView(_ wv: WKWebView, createWebViewWith cfg: WKWebViewConfiguration,
                     for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if action.targetFrame == nil { wv.load(action.request) }
            return nil
        }
    }
}
