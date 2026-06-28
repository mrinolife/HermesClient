import SwiftUI

@main
struct HermesWatchApp: App {
    @State private var confirmed = 0
    @State private var pending = 0
    @State private var lastScan = "never"
    
    let sharedDefaults = UserDefaults(suiteName: "group.com.jznle.hermesclient")
    
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 16) {
                        // Pipeline status
                        VStack(spacing: 8) {
                            HStack(spacing: 24) {
                                VStack {
                                    Text("\(confirmed)")
                                        .font(.system(size: 36, weight: .bold))
                                        .foregroundColor(.green)
                                    Text("confirmed")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                VStack {
                                    Text("\(pending)")
                                        .font(.system(size: 36, weight: .bold))
                                        .foregroundColor(.orange)
                                    Text("pending")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            HStack {
                                Image(systemName: "clock")
                                Text("last scan \(lastScan)")
                            }
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        
                        // Quick actions
                        Button(action: { openPhone() }) {
                            Label("Open Hermes", systemImage: "arrow.up.forward.app")
                                .frame(maxWidth: .infinity)
                        }
                        .tint(.purple)
                    }
                    .padding()
                }
                .navigationTitle("Hermes")
            }
            .onAppear { loadData() }
            .refreshable { loadData() }
        }
    }
    
    func loadData() {
        confirmed = sharedDefaults?.integer(forKey: "pipeline_confirmed") ?? 0
        pending = sharedDefaults?.integer(forKey: "pipeline_pending") ?? 0
        lastScan = sharedDefaults?.string(forKey: "pipeline_last_scan") ?? "never"
    }
    
    func openPhone() {
        // Open companion iPhone app
        WKApplication.shared().openSystemURL(URL(string: "hermesclient://")!)
    }
}
