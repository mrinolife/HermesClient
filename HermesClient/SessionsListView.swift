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
            sessionList
                .searchable(text: $searchText)
                .navigationTitle("Recent Sessions")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { dismissToolbar }
        }
    }
    
    @ViewBuilder
    private var sessionList: some View {
        if appState.cachedSessions.isEmpty {
            emptyState
        } else {
            List {
                ForEach(filteredSessions) { session in
                    Button { selectSession(session.id) } label: { sessionRow(session) }
                }
                .onDelete { appState.cachedSessions.remove(atOffsets: $0) }
            }
        }
    }
    
    @ViewBuilder
    private var emptyState: some View {
        ContentUnavailableView(
            "No Cached Sessions",
            systemImage: "clock.badge.questionmark",
            description: Text("Sessions will appear here after you use the app.")
        )
    }
    
    private func sessionRow(_ session: CachedSession) -> some View {
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
    
    private func selectSession(_ id: String) {
        openSession(id)
        dismiss()
    }
    
    private var dismissToolbar: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button("Done") { dismiss() }
        }
    }
    
    private func openSession(_ id: String) {
        // Will navigate WebView to session URL
        // appState.serverURL + /session/ + id
    }
}
