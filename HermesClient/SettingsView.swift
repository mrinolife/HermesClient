import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var serverURL: String = ""
    @State private var ttsServerURL: String = ""
    @State private var testResult: String?
    @State private var ttsTestResult: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Hermes Server") {
                    TextField("Server URL", text: $serverURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onAppear { serverURL = appState.serverURL }
                    
                    Button("Test Connection") { testConnection() }
                    
                    if let result = testResult {
                        Text(result)
                            .font(.caption)
                            .foregroundColor(result.contains("✅") ? .green : .red)
                    }
                }
                
                Section("Voice Server (CosyVoice / Ina's Voice)") {
                    TextField("TTS Server URL", text: $ttsServerURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onAppear {
                            ttsServerURL = UserDefaults.standard.string(forKey: "tts_server_url")
                                ?? "https://aibo.tail065eca.ts.net:5055"
                        }
                    
                    Button("Test Voice") { testTTS() }
                    
                    if let result = ttsTestResult {
                        Text(result)
                            .font(.caption)
                            .foregroundColor(result.contains("✅") ? .green : .red)
                    }
                }
                
                Section("Profile") {
                    Picker("Active Profile", selection: $appState.selectedProfile) {
                        ForEach(appState.profiles, id: \.self) { profile in
                            Text(profile).tag(profile)
                        }
                    }
                }
                
                Section("Model") {
                    Picker("Default Model", selection: $appState.activeModel) {
                        ForEach(appState.models, id: \.self) { model in
                            Text(model.components(separatedBy: "/").last ?? model).tag(model)
                        }
                    }
                }
                
                Section("Appearance") {
                    Toggle("Dark Mode", isOn: $appState.isDarkMode)
                }
                
                Section("Cache") {
                    HStack {
                        Text("Cached Sessions")
                        Spacer()
                        Text("\(appState.cachedSessions.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Clear Cache", role: .destructive) {
                        UserDefaults.standard.removeObject(forKey: "cached_sessions")
                        appState.cachedSessions = []
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Hermes Server")
                        Spacer()
                        Text(appState.serverURL)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    HStack {
                        Text("Voice Server")
                        Spacer()
                        Text(ttsServerURL)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveSettings()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func saveSettings() {
        if !serverURL.isEmpty {
            var url = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
            if !url.hasPrefix("http") { url = "https://\(url)" }
            if url.hasSuffix("/") { url = String(url.dropLast()) }
            appState.serverURL = url
        }
        if !ttsServerURL.isEmpty {
            var url = ttsServerURL.trimmingCharacters(in: .whitespacesAndNewlines)
            if !url.hasPrefix("http") { url = "https://\(url)" }
            if url.hasSuffix("/") { url = String(url.dropLast()) }
            UserDefaults.standard.set(url, forKey: "tts_server_url")
        }
    }
    
    private func testConnection() {
        testResult = "Testing..."
        var url = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.hasPrefix("http") { url = "https://\(url)" }
        
        guard let testURL = URL(string: "\(url)/health") ?? URL(string: url) else {
            testResult = "❌ Invalid URL"
            return
        }
        
        URLSession.shared.dataTask(with: testURL) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    testResult = "❌ \(error.localizedDescription)"
                } else if let httpResponse = response as? HTTPURLResponse {
                    testResult = "✅ Connected (\(httpResponse.statusCode))"
                } else {
                    testResult = "✅ Connected"
                }
            }
        }.resume()
    }
    
    private func testTTS() {
        ttsTestResult = "Testing..."
        saveSettings()
        let urlStr = UserDefaults.standard.string(forKey: "tts_server_url")
            ?? "https://aibo.tail065eca.ts.net:5055"
        
        guard let url = URL(string: "\(urlStr)/health") else {
            ttsTestResult = "❌ Invalid URL"
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    ttsTestResult = "❌ \(error.localizedDescription)"
                } else if let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode == 200 {
                    ttsTestResult = "✅ CosyVoice ready (Ina's voice)"
                } else {
                    ttsTestResult = "❌ Server not ready"
                }
            }
        }.resume()
    }
}
