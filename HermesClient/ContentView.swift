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
    @StateObject private var voice = VoiceManager()
    
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
                        onAssistantResponse: { text in
                            // Speak the assistant's response
                            voice.speak(text)
                        },
                        refreshTrigger: $refreshTrigger,
                        pendingVoiceInput: $pendingVoiceInput
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
                
                // Voice indicator bar
                if voice.isListening || voice.isSpeaking {
                    HStack {
                        Image(systemName: voice.isListening ? "waveform" : "speaker.wave.2")
                            .foregroundColor(voice.isListening ? .green : accentColor)
                        
                        Text(voice.isListening 
                             ? (voice.transcript.isEmpty ? "Listening..." : voice.transcript)
                             : "Speaking...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Button(action: { voice.interrupt() }) {
                            Image(systemName: "stop.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .transition(.move(edge: .bottom))
                }
            }
            .navigationTitle(webViewTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button(action: { appState.showSettings = true }) {
                        Image(systemName: "gear")
                    }
                    
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
                
                ToolbarItemGroup(placement: .bottomBar) {
                    // Voice button — main action
                    Button(action: toggleVoice) {
                        Image(systemName: voice.isListening ? "waveform.circle.fill" : "mic.circle.fill")
                            .font(.title2)
                            .foregroundColor(voice.isListening ? .green : accentColor)
                    }
                    
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
            .onAppear {
                Task { await voice.requestPermission() }
            }
        }
    }
    
    private var accentColor: Color {
        Color(red: 139/255, green: 92/255, blue: 246/255)  // Ina purple
    }
    
    private func toggleVoice() {
        if voice.isListening {
            voice.stopListening()
        } else if voice.isSpeaking {
            voice.interrupt()
        } else {
            // Request mic permission and start
            Task {
                let granted = await voice.requestPermission()
                if granted {
                    voice.startListening { text in
                        guard !text.isEmpty else { return }
                        // Inject the transcribed text into the WebView
                        pendingVoiceInput = text
                    }
                }
            }
        }
    }
    
    private func runPipelineCheck() {
        // Custom: inject pipeline status into WebView
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
