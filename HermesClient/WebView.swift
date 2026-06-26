import SwiftUI
import WebKit
import Combine

struct WebView: UIViewRepresentable {
    @EnvironmentObject var appState: AppState
    let url: URL
    let onTitleChange: (String) -> Void
    let onLoadingChange: (Bool) -> Void
    let onURLChange: (URL) -> Void
    
    @Binding var refreshTrigger: UUID
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        let userContentController = WKUserContentController()
        
        // Inject custom JS bridge
        if let bridgeJS = try? String(contentsOfFile: Bundle.main.path(forResource: "jsbridge", ofType: "js") ?? "") {
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
        
        // Re-inject dark mode if toggled
        let darkModeJS = """
        document.documentElement.dataset.theme = '\(appState.isDarkMode ? "dark" : "light")';
        document.body.classList.toggle('dark', \(appState.isDarkMode));
        """
        webView.evaluateJavaScript(darkModeJS, completionHandler: nil)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: WebView
        var lastRefresh: UUID = UUID()
        private var titleObserver: NSKeyValueObservation?
        private var loadingObserver: NSKeyValueObservation?
        private var urlObserver: NSKeyValueObservation?
        
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
        
        private func handleError(_ webView: WKWebView, error: Error) {
            let nsError = error as NSError
            if nsError.code == NSURLErrorCancelled { return }
            
            // Show error page
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
        
        // Handle new windows/target=_blank
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
        
        deinit {
            titleObserver?.invalidate()
            loadingObserver?.invalidate()
            urlObserver?.invalidate()
        }
    }
}
