import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// Lock screen and Dynamic Island views for the running session. Draws
/// `TimerActivityAttributes.ContentState` and nothing else: Runner starts,
/// updates and ends the activity (LiveActivityController.swift) when
/// Flutter says so.
struct TimerLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: TimerActivityAttributes.self) { context in
      // Lock screen, and the banner on phones without a Dynamic Island.
      HStack(spacing: 12) {
        ActivityDot(color: context.state.color)
        VStack(alignment: .leading, spacing: 2) {
          Text("Tracking")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(context.state.activityName)
            .font(.headline)
            .lineLimit(1)
        }
        Spacer(minLength: 8)
        ElapsedText(startedAt: context.state.startedAt)
          .font(.title2)
          .frame(maxWidth: 110, alignment: .trailing)
        StopButton(sessionId: context.state.sessionId)
      }
      .padding()
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          ActivityDot(color: context.state.color)
            .padding(.leading, 4)
        }
        DynamicIslandExpandedRegion(.center) {
          Text(context.state.activityName)
            .font(.headline)
            .lineLimit(1)
        }
        DynamicIslandExpandedRegion(.trailing) {
          ElapsedText(startedAt: context.state.startedAt)
            .frame(maxWidth: 84, alignment: .trailing)
        }
        DynamicIslandExpandedRegion(.bottom) {
          StopButton(sessionId: context.state.sessionId)
        }
      } compactLeading: {
        ActivityDot(color: context.state.color)
      } compactTrailing: {
        ElapsedText(startedAt: context.state.startedAt)
          .font(.caption2)
          .frame(maxWidth: 52)
      } minimal: {
        ActivityDot(color: context.state.color)
      }
    }
  }
}

/// The activity's swatch. Flutter stores it as ARGB; without one it is the
/// app accent (AppColors.accent).
private struct ActivityDot: View {
  let color: Int?

  var body: some View {
    Circle()
      .fill(swatch)
      .frame(width: 12, height: 12)
  }

  private var swatch: Color {
    let argb = color ?? 0xFF4F_B8A8
    return Color(
      .sRGB,
      red: Double((argb >> 16) & 0xFF) / 255,
      green: Double((argb >> 8) & 0xFF) / 255,
      blue: Double(argb & 0xFF) / 255,
      opacity: 1
    )
  }
}

/// A system timer text: it keeps counting while the app is not running.
/// It asks for all the width it can get, so every caller caps it.
private struct ElapsedText: View {
  let startedAt: Date

  var body: some View {
    Text(timerInterval: startedAt...Date.distantFuture, countsDown: false)
      .monospacedDigit()
      .multilineTextAlignment(.trailing)
  }
}

private struct StopButton: View {
  let sessionId: Int

  var body: some View {
    Button(intent: StopTimerIntent(sessionId: sessionId)) {
      Image(systemName: "stop.fill")
    }
    .buttonStyle(.borderedProminent)
    .buttonBorderShape(.circle)
    .tint(.red)
    .accessibilityLabel("Stop")
  }
}
