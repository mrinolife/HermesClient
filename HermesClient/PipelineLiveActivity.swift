import WidgetKit
import SwiftUI
import ActivityKit

/// Live Activity for pipeline scan progress — shows on Dynamic Island / Lock Screen.
struct PipelineActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable & Hashable {
        var confirmed: Int
        var pending: Int
        var progress: Double  // 0.0 to 1.0
    }
    var scanName: String
}

struct PipelineLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PipelineActivityAttributes.self) { context in
            // Lock screen / banner
            HStack {
                VStack(alignment: .leading) {
                    Text("🎯 \(context.attributes.scanName)")
                        .font(.headline)
                    HStack {
                        Label("\(context.state.confirmed) confirmed", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Label("\(context.state.pending) pending", systemImage: "clock.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                }
                Spacer()
                CircularProgressView(progress: context.state.progress)
                    .frame(width: 36, height: 36)
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.8))
            
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("\(context.state.confirmed) ✅", systemImage: "target")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Label("\(context.state.pending) ⏳", systemImage: "clock")
                }
                DynamicIslandExpandedRegion(.center) {
                    CircularProgressView(progress: context.state.progress)
                        .frame(width: 24, height: 24)
                }
            } compactLeading: {
                Label("\(context.state.confirmed)", systemImage: "checkmark")
                    .foregroundColor(.green)
            } compactTrailing: {
                CircularProgressView(progress: context.state.progress)
                    .frame(width: 16, height: 16)
            } minimal: {
                CircularProgressView(progress: context.state.progress)
                    .frame(width: 12, height: 12)
            }
        }
    }
}

struct CircularProgressView: View {
    let progress: Double
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.purple, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}
