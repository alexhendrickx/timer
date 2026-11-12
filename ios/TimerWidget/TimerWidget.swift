import SwiftUI
import WidgetKit

/// One entry in the shared snapshot Flutter writes via
/// `WidgetSnapshotWriter` (lib/core/platform/ios/widget_snapshot_writer.dart)
/// to `<app group>/activity_snapshot.json`. Field names match that JSON
/// exactly — this struct has no independent source of truth.
struct ActivitySnapshot: Decodable {
  let activityId: Int
  let name: String
  let color: Int?
  let todaySeconds: Int
}

private let appGroupId = "group.com.alexhendrickx.timer"
private let snapshotFileName = "activity_snapshot.json"

func readActivitySnapshot() -> [ActivitySnapshot] {
  guard
    let containerURL = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroupId
    )
  else { return [] }
  let fileURL = containerURL.appendingPathComponent(snapshotFileName)
  guard let data = try? Data(contentsOf: fileURL) else { return [] }
  return (try? JSONDecoder().decode([ActivitySnapshot].self, from: data)) ?? []
}

struct TimerWidgetEntry: TimelineEntry {
  let date: Date
  let activities: [ActivitySnapshot]
}

struct TimerWidgetProvider: TimelineProvider {
  func placeholder(in context: Context) -> TimerWidgetEntry {
    TimerWidgetEntry(date: Date(), activities: [])
  }

  func getSnapshot(
    in context: Context,
    completion: @escaping (TimerWidgetEntry) -> Void
  ) {
    completion(TimerWidgetEntry(date: Date(), activities: readActivitySnapshot()))
  }

  func getTimeline(
    in context: Context,
    completion: @escaping (Timeline<TimerWidgetEntry>) -> Void
  ) {
    let entry = TimerWidgetEntry(date: Date(), activities: readActivitySnapshot())
    // Re-read on each refresh (widgets don't run live code); the app
    // reschedules the WidgetKit timeline via WidgetCenter whenever it
    // calls WidgetSnapshotWriter.sync() (see Task 5 wiring).
    completion(Timeline(entries: [entry], policy: .atEnd))
  }
}

struct TimerWidgetView: View {
  let entry: TimerWidgetEntry

  var body: some View {
    if entry.activities.isEmpty {
      // No activities, or the snapshot hasn't been written yet (first
      // launch): an "open app" affordance, never a crash or blank tile.
      Link(destination: URL(string: "timer://quick-start")!) {
        VStack(spacing: 4) {
          Image(systemName: "play.circle")
          Text("Open Timer")
            .font(.caption)
        }
      }
    } else {
      VStack(alignment: .leading, spacing: 6) {
        ForEach(entry.activities.prefix(4), id: \.activityId) { activity in
          Link(destination: URL(string: "timer://quick-start?activityId=\(activity.activityId)")!) {
            HStack {
              Text(activity.name)
                .font(.caption)
                .lineLimit(1)
              Spacer()
              Text(formatSeconds(activity.todaySeconds))
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
          }
        }
      }
      .padding(8)
    }
  }
}

private func formatSeconds(_ seconds: Int) -> String {
  let h = seconds / 3600
  let m = (seconds % 3600) / 60
  return String(format: "%d:%02d", h, m)
}

struct TimerWidget: Widget {
  let kind = "TimerWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: TimerWidgetProvider()) { entry in
      TimerWidgetView(entry: entry)
    }
    .configurationDisplayName("Timer Quick Start")
    .description("One-tap start for your activities.")
    .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
  }
}
