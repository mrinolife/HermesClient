import SwiftUI

@main
struct HermesClientApp: App {
    @StateObject private var appState = AppState()
    @State private var pendingShareURL: URL?
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                .onAppear {
                    setupAppearance()
                }
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return }
        
        if components.host == "share" {
            if let text = components.queryItems?.first(where: { $0.name == "text" })?.value {
                // Inject text into WebView via JS
                let js = """
                (function() {
                    const input = document.querySelector('textarea, [contenteditable]');
                    if (input) {
                        input.value = '\(text.replacingOccurrences(of: "'", with: "\\'"))';
                        input.dispatchEvent(new Event('input', { bubbles: true }));
                    }
                })();
                """
                // TODO: pass to WebView via notification
                NotificationCenter.default.post(name: .init("injectJS"), object: nil, userInfo: ["js": js])
            }
        }
    }
    
    private func setupAppearance() {
        UINavigationBar.appearance().tintColor = UIColor(red: 0.42, green: 0.58, blue: 0.96, alpha: 1)
        UIToolbar.appearance().tintColor = UIColor(red: 0.42, green: 0.58, blue: 0.96, alpha: 1)
    }
}
