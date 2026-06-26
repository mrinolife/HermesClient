import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var serverURL: String = ""
    @State private var testResult: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Server") {
                    TextField("Server URL", text: $serverURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onAppear { serverURL = appState.serverURL }
                    
                    Button("Test Connection") {
                        testConnection()
                    }
                    
                    if let result = testResult {
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
                        Text("Server")
                        Spacer()
                        Text(appState.serverURL)
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
                        if !serverURL.isEmpty {
                            // Normalize URL
                            var url = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !url.hasPrefix("http") {
                                url = "https://\(url)"
                            }
                            if url.hasSuffix("/") {
                                url = String(url.dropLast())
                            }
                            appState.serverURL = url
                        }
                        dismiss()
                    }
                }
            }
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
}
