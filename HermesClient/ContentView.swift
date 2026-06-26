import SwiftUI
import WebKit

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var webViewTitle = "Hermes"
    @State private var isLoading = false
    @State private var refreshTrigger = UUID()
    @State private var canGoBack = false
    @State private var showSessions = false
    @State private var webView: WKWebView?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // WebView
                if let url = URL(string: appState.serverURL) {
                    WebView(
                        url: url,
                        onTitleChange: { webViewTitle = $0 },
                        onLoadingChange: { isLoading = $0 },
                        onURLChange: { _ in },
                        refreshTrigger: $refreshTrigger
                    )
                    .edgesIgnoringSafeArea(.bottom)
                } else {
                    VStack {
                        Image(systemName: "link.broken")
                            .font(.system(size: 48))
                            .foregroundColor(.red)
                        Text("Invalid server URL")
                            .font(.title3)
                            .padding(.top)
                        Button("Configure in Settings") {
                            appState.showSettings = true
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .navigationTitle(webViewTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button(action: { appState.showSettings = true }) {
                        Image(systemName: "gear")
                    }
                    
                    // Pipeline status button (your custom addition)
                    Button(action: { runPipelineCheck() }) {
                        Image(systemName: "target")
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    
                    Button(action: { refreshTrigger = UUID() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    
                    Button(action: { showSessions.toggle() }) {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
                
                // Bottom toolbar
                ToolbarItemGroup(placement: .bottomBar) {
                    Button(action: { /* back */ }) {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(!canGoBack)
                    
                    Spacer()
                    
                    Button(action: { showShareSheet() }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    
                    Spacer()
                    
                    Menu {
                        Picker("Profile", selection: $appState.selectedProfile) {
                            ForEach(appState.profiles, id: \.self) { profile in
                                Text(profile).tag(profile)
                            }
                        }
                        
                        Picker("Model", selection: $appState.activeModel) {
                            ForEach(appState.models, id: \.self) { model in
                                Text(model.components(separatedBy: "/").last ?? model).tag(model)
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $appState.showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showSessions) {
                SessionsListView()
            }
            .preferredColorScheme(appState.isDarkMode ? .dark : .light)
        }
    }
    
    private func runPipelineCheck() {
        // Custom: inject pipeline status into WebView
        // This calls the WebUI's API and shows a native alert
        // TODO: Wire up to actual edge-pipeline status
    }
    
    private func showShareSheet() {
        guard let url = URL(string: appState.serverURL) else { return }
        let activityVC = UIActivityViewController(
            activityItems: [url, webViewTitle],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}
