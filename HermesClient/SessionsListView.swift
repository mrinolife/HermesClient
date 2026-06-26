import SwiftUI

struct SessionsListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    
    var filteredSessions: [CachedSession] {
        if searchText.isEmpty { return appState.cachedSessions }
        return appState.cachedSessions.filter {
            $0.title?.localizedCaseInsensitiveContains(searchText) == true ||
            $0.lastMessage?.localizedCaseInsensitiveContains(searchText) == true
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if appState.cachedSessions.isEmpty {
                    ContentUnavailableView(
                        "No Cached Sessions",
                        systemImage: "clock.badge.questionmark",
                        description: Text("Sessions will appear here after you use the app.")
                    )
                } else {
                    ForEach(filteredSessions) { session in
                        Button(action: {
                            // Navigate to session in WebView
                            openSession(session.id)
                            dismiss()
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.title ?? "Untitled Session")
                                    .font(.headline)
                                    .lineLimit(1)
                                
                                if let last = session.lastMessage {
                                    Text(last)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                                
                                Text(session.timestamp, style: .relative)
                                    .font(.caption2)
                                    .foregroundColor(.tertiary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete { indexSet in
                        appState.cachedSessions.remove(atOffsets: indexSet)
                    }
                }
            }
            .searchable(text: $searchText)
            .navigationTitle("Recent Sessions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func openSession(_ id: String) {
        // Will navigate WebView to session URL
        // appState.serverURL + /session/ + id
    }
}
