import SwiftUI
import WebKit

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var webViewTitle = "Hermes"
    @State private var isLoading = false
    @State private var refreshTrigger = UUID()
    @State private var pendingVoiceInput: String?
    @State private var canGoBack = false
    @State private var showSessions = false
    @State private var serverStatus: ServerStatus = .checking
    @State private var isReconnecting = false
    @StateObject private var voice = VoiceManager()
    
    enum ServerStatus { case checking, reachable, unreachable }
    
    private let healthTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // WebView
                if let url = URL(string: appState.serverURL) {
                    WebView(
                        url: url,
                        onTitleChange: { webViewTitle = $0 },
                        onLoadingChange: { isLoading = $0; if $0 { isReconnecting = false } },
                        onURLChange: { _ in },
                        onAssistantResponse: { voice.speak($0) },
                        refreshTrigger: $refreshTrigger,
                        pendingVoiceInput: $pendingVoiceInput,
                        isReconnecting: $isReconnecting
                    )
                    .edgesIgnoringSafeArea(.bottom)
                } else {
                    VStack {
                        Image(systemName: "link.broken")
                            .font(.system(size: 48))
                            .foregroundColor(.red)
                        Text("Invalid server URL").font(.title3).padding(.top)
                        Button("Configure in Settings") { appState.showSettings = true }.padding(.top, 8)
                    }
                }
                
                // Voice indicator
                if voice.isListening || voice.isSpeaking {
                    HStack {
                        Image(systemName: voice.isListening ? "waveform" : "speaker.wave.2")
                            .foregroundColor(voice.isListening ? .green : accentColor)
                        Text(voice.isListening
                             ? (voice.transcript.isEmpty ? "Listening..." : voice.transcript)
                             : "Speaking...")
                            .font(.caption).foregroundColor(.secondary).lineLimit(1)
                        Spacer()
                        Button { voice.interrupt() } label: {
                            Image(systemName: "stop.circle.fill").foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .transition(.move(edge: .bottom))
                }
                
                // Reconnecting banner
                if isReconnecting {
                    HStack {
                        ProgressView().scaleEffect(0.7)
                        Text("Connection lost — reconnecting...").font(.caption).foregroundColor(.secondary)
                    }
                    .padding(6).frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                }
            }
            .navigationTitle(webViewTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    // Server status dot
                    Circle().fill(serverStatusColor).frame(width: 8, height: 8)
                    
                    Button { appState.showSettings = true } label: {
                        Image(systemName: "gear")
                    }
                    
                    // Pipeline badge
                    Button { runPipelineCheck() } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "target")
                            if appState.pipelineConfirmed > 0 || appState.pipelinePending > 0 {
                                Text("\(appState.pipelineConfirmed)✓")
                                    .font(.caption2).foregroundColor(.green)
                            }
                        }
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if isLoading {
                        ProgressView().scaleEffect(0.8)
                    }
                    Button { refreshTrigger = UUID() } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    Button { showSessions.toggle() } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
                
                ToolbarItemGroup(placement: .bottomBar) {
                    Button(action: toggleVoice) {
                        Image(systemName: voice.isListening ? "waveform.circle.fill" : "mic.circle.fill")
                            .font(.title2)
                            .foregroundColor(voice.isListening ? .green : accentColor)
                    }
                    
                    Spacer()
                    
                    Button { showShareSheet() } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    
                    Spacer()
                    
                    Menu {
                        Picker("Profile", selection: $appState.selectedProfile) {
                            ForEach(appState.profiles, id: \.self) { Text($0).tag($0) }
                        }
                        Picker("Model", selection: $appState.activeModel) {
                            ForEach(appState.models, id: \.self) {
                                Text($0.components(separatedBy: "/").last ?? $0).tag($0)
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $appState.showSettings) { SettingsView() }
            .sheet(isPresented: $showSessions) { SessionsListView() }
            .preferredColorScheme(appState.isDarkMode ? .dark : .light)
            .onAppear {
                voice.configure(ttsURL: appState.ttsServerURL)
                Task { await voice.requestPermission() }
                checkServer()
            }
            .onReceive(healthTimer) { _ in checkServer() }
        }
    }
    
    private var serverStatusColor: Color {
        switch serverStatus {
        case .checking: return .yellow
        case .reachable: return .green
        case .unreachable: return .red
        }
    }
    
    private var accentColor: Color {
        Color(red: 139/255, green: 92/255, blue: 246/255)
    }
    
    private func checkServer() {
        guard let url = URL(string: appState.serverURL) else { return }
        serverStatus = .checking
        URLSession.shared.dataTask(with: url) { _, resp, _ in
            DispatchQueue.main.async {
                if let http = resp as? HTTPURLResponse, (200...399).contains(http.statusCode) {
                    serverStatus = .reachable
                } else {
                    serverStatus = .unreachable
                }
            }
        }.resume()
    }
    
    private func toggleVoice() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        if voice.isListening {
            voice.stopListening()
        } else if voice.isSpeaking {
            voice.interrupt()
        } else {
            Task {
                let granted = await voice.requestPermission()
                if granted {
                    voice.startListening { text in
                        guard !text.isEmpty else { return }
                        Task { @MainActor in pendingVoiceInput = text }
                    }
                }
            }
        }
    }
    
    private func runPipelineCheck() {
        // Opens pipeline view — placeholder for now
    }
    
    private func showShareSheet() {
        guard let url = URL(string: appState.serverURL) else { return }
        let vc = UIActivityViewController(activityItems: [url, webViewTitle], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(vc, animated: true)
        }
    }
}
