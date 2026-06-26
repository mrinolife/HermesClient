import Foundation
import Combine
import SwiftUI

@MainActor
class AppState: ObservableObject {
    @Published var serverURL: String {
        didSet { UserDefaults.standard.set(serverURL, forKey: "server_url") }
    }
    @Published var selectedProfile: String {
        didSet { UserDefaults.standard.set(selectedProfile, forKey: "selected_profile") }
    }
    @Published var activeModel: String {
        didSet { UserDefaults.standard.set(activeModel, forKey: "active_model") }
    }
    @Published var isDarkMode: Bool {
        didSet { UserDefaults.standard.set(isDarkMode, forKey: "dark_mode") }
    }
    @Published var webViewTitle: String = "Hermes"
    @Published var isLoading: Bool = false
    @Published var showSettings: Bool = false
    @Published var showShare: Bool = false
    
    // Cached sessions (simplified)
    @Published var cachedSessions: [CachedSession] = []
    
    let profiles = ["default", "bounty", "life"]
    let models = [
        "deepseek/deepseek-v4-flash",
        "anthropic/claude-sonnet-4",
        "anthropic/claude-opus-4"
    ]
    
    init() {
        self.serverURL = UserDefaults.standard.string(forKey: "server_url") ?? "https://aibo.tail065eca.ts.net:8787"
        self.selectedProfile = UserDefaults.standard.string(forKey: "selected_profile") ?? "bounty"
        self.activeModel = UserDefaults.standard.string(forKey: "active_model") ?? "deepseek/deepseek-v4-flash"
        self.isDarkMode = UserDefaults.standard.object(forKey: "dark_mode") as? Bool ?? true
        loadCachedSessions()
    }
    
    func loadCachedSessions() {
        // Load from local cache
        if let data = UserDefaults.standard.data(forKey: "cached_sessions"),
           let sessions = try? JSONDecoder().decode([CachedSession].self, from: data) {
            cachedSessions = sessions
        }
    }
    
    func cacheSession(_ session: CachedSession) {
        if let idx = cachedSessions.firstIndex(where: { $0.id == session.id }) {
            cachedSessions[idx] = session
        } else {
            cachedSessions.insert(session, at: 0)
        }
        // Keep last 50
        if cachedSessions.count > 50 { cachedSessions = Array(cachedSessions.prefix(50)) }
        saveCachedSessions()
    }
    
    private func saveCachedSessions() {
        if let data = try? JSONEncoder().encode(cachedSessions) {
            UserDefaults.standard.set(data, forKey: "cached_sessions")
        }
    }
}

struct CachedSession: Codable, Identifiable {
    let id: String
    let title: String?
    let lastMessage: String?
    let timestamp: Date
}
