import SwiftUI
import WebKit
import Combine

struct WebView: UIViewRepresentable {
    @EnvironmentObject var appState: AppState
    let url: URL
    let onTitleChange: (String) -> Void
    let onLoadingChange: (Bool) -> Void
    let onURLChange: (URL) -> Void
    let onAssistantResponse: (String) -> Void  // NEW: response from JS bridge
    
    @Binding var refreshTrigger: UUID
    @Binding var pendingVoiceInput: String?  // NEW: text to inject and send
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        let userContentController = WKUserContentController()
        
        // Add message handler for JS bridge responses
        userContentController.add(context.coordinator, name: "hermesResponse")
        
        // Inject custom JS bridge
        if let bridgePath = Bundle.main.path(forResource: "jsbridge", ofType: "js"),
           let bridgeJS = try? String(contentsOfFile: bridgePath) {
            let script = WKUserScript(source: bridgeJS, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
            userContentController.addUserScript(script)
        }
        
        // Inject dark mode override
        let darkModeJS = """
        document.documentElement.dataset.theme = '\(appState.isDarkMode ? "dark" : "light")';
        """
        let darkScript = WKUserScript(source: darkModeJS, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        userContentController.addUserScript(darkScript)
        
        config.userContentController = userContentController
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .always
        
        // Performance settings
        webView.configuration.preferences.setValue(true, forKey: "fullScreenEnabled")
        if #available(iOS 18.0, *) {
            webView.configuration.upgradeKnownHostsToHTTPS = false
        }
        
        webView.load(URLRequest(url: url))
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        if refreshTrigger != context.coordinator.lastRefresh {
            context.coordinator.lastRefresh = refreshTrigger
            webView.reload()
        }
        
        // Handle pending voice input — inject into chat and send
        if let text = pendingVoiceInput {
            context.coordinator.lastPendingText = text
            
            let escaped = text
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\n", with: "\\n")
            
            let js = """
            (function() {
                const input = document.querySelector('textarea, [contenteditable="true"], .composer-input, .input-area textarea');
                if (input) {
                    const nativeInputValueSetter = Object.getOwnPropertyDescriptor(window.HTMLTextAreaElement.prototype, 'value').set;
                    nativeInputValueSetter.call(input, '\(escaped)');
                    input.dispatchEvent(new Event('input', { bubbles: true }));
                    
                    // Try to find and click the send button
                    const sendBtn = document.querySelector('button.send-btn, button[aria-label="Send"], .send-button, button:has(svg)');
                    if (sendBtn) {
                        setTimeout(() => sendBtn.click(), 100);
                    }
                    
                    // Notify that voice input was injected
                    window.webkit.messageHandlers.hermesResponse.postMessage({type: 'voice_sent', text: '\(escaped)'});
                }
            })();
            """
            webView.evaluateJavaScript(js) { _, error in
                if let error = error {
                    print("Voice injection error: \(error)")
                }
            }
            
            // Clear pending on next tick
            DispatchQueue.main.async {
                self.pendingVoiceInput = nil
            }
        }
        
        // Re-inject dark mode if toggled
        let darkModeJS = """
        document.documentElement.dataset.theme = '\(appState.isDarkMode ? "dark" : "light")';
        document.body.classList.toggle('dark', \(appState.isDarkMode));
        """
        webView.evaluateJavaScript(darkModeJS, completionHandler: nil)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        var parent: WebView
        var lastRefresh: UUID = UUID()
        var lastPendingText: String = ""
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.onLoadingChange(true)
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.onLoadingChange(false)
            if let title = webView.title {
                parent.onTitleChange(title)
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.onLoadingChange(false)
            handleError(webView, error: error)
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.onLoadingChange(false)
            handleError(webView, error: error)
        }
        
        // MARK: - JS Message Handler
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let type = body["type"] as? String else { return }
            
            if type == "assistant_response", let text = body["text"] as? String {
                parent.onAssistantResponse(text)
            }
        }
        
        private func handleError(_ webView: WKWebView, error: Error) {
            let nsError = error as NSError
            if nsError.code == NSURLErrorCancelled { return }
            
            let html = """
            <html><body style="display:flex;align-items:center;justify-content:center;height:100vh;
            background:#1a1a2e;color:#ccc;font-family:system-ui;text-align:center;padding:20px;">
            <div><h1 style="color:#e74c3c;">Connection Error</h1>
            <p>\(nsError.localizedDescription)</p>
            <p style="color:#888;font-size:14px;margin-top:20px;">
            Make sure your server is running and reachable.<br/>
            Go to Settings to update the server URL.</p>
            </div></body></html>
            """
            webView.loadHTMLString(html, baseURL: nil)
        }
        
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
    }
}
