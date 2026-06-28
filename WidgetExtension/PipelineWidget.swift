import WidgetKit
import SwiftUI

/// Pipeline status widget — shows confirmed/pending/last scan at a glance.
struct PipelineWidget: Widget {
    let kind: String = "com.jznle.hermesclient.pipeline"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PipelineProvider()) { entry in
            PipelineWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Pipeline Status")
        .description("Bug bounty pipeline at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct PipelineEntry: TimelineEntry {
    let date: Date
    let confirmed: Int
    let pending: Int
    let lastScan: String
    let serverURL: String
}

struct PipelineProvider: TimelineProvider {
    let defaults = UserDefaults(suiteName: "group.com.jznle.hermesclient")
    
    func placeholder(in context: Context) -> PipelineEntry {
        PipelineEntry(date: Date(), confirmed: 3, pending: 2, lastScan: "2h ago", serverURL: "")
    }

    func getSnapshot(in context: Context, completion: @escaping (PipelineEntry) -> ()) {
        let entry = loadEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PipelineEntry>) -> ()) {
        let entry = loadEntry()
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
    
    private func loadEntry() -> PipelineEntry {
        let confirmed = defaults?.integer(forKey: "pipeline_confirmed") ?? 0
        let pending = defaults?.integer(forKey: "pipeline_pending") ?? 0
        let lastScan = defaults?.string(forKey: "pipeline_last_scan") ?? "never"
        let server = defaults?.string(forKey: "server_url") ?? ""
        return PipelineEntry(date: Date(), confirmed: confirmed, pending: pending, lastScan: lastScan, serverURL: server)
    }
}

struct PipelineWidgetView: View {
    var entry: PipelineEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("🎯 Pipeline")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Circle()
                    .fill(Color.pink.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
            
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("\(entry.confirmed)")
                        .font(.title.weight(.bold))
                        .foregroundColor(.green)
                    Text("confirmed")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                VStack(alignment: .leading) {
                    Text("\(entry.pending)")
                        .font(.title.weight(.bold))
                        .foregroundColor(.orange)
                    Text("pending")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            HStack {
                Image(systemName: "clock")
                    .font(.caption2)
                Text("last scan \(entry.lastScan)")
                    .font(.caption2)
                Spacer()
            }
            .foregroundColor(.tertiary)
        }
        .padding(12)
    }
}
