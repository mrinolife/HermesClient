import SwiftUI
import WebKit

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var webViewTitle = "Hermes"
    @State private var isLoading = false
    @State private var refreshTrigger = UUID()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let url = URL(string: appState.serverURL) {
                    WebView(
                        url: url,
                        onTitleChange: { webViewTitle = $0 },
                        onLoadingChange: { isLoading = $0 },
                        onURLChange: { _ in },
                        onAssistantResponse: { _ in },
                        refreshTrigger: $refreshTrigger,
                        pendingVoiceInput: .constant(nil)
                    )
                    .edgesIgnoringSafeArea(.bottom)
                } else {
                    Text("Invalid server URL")
                }
            }
            .navigationTitle(webViewTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isLoading { ProgressView().scaleEffect(0.8) }
                    Button(action: { refreshTrigger = UUID() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $appState.showSettings) {
                SettingsView()
            }
            .preferredColorScheme(appState.isDarkMode ? .dark : .light)
        }
    }
}
