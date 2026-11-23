import ActivityKit
import Flutter

/// Native side of the `timer/live_activity` channel. Flutter's
/// LiveActivityMirror decides what to show; this only carries it out. Each
/// call replies after its ActivityKit work is done and Flutter sends one
/// call at a time, so a late `end` can never land on a newer activity.
enum LiveActivityController {
  static func register(with messenger: FlutterBinaryMessenger) -> FlutterMethodChannel {
    let channel = FlutterMethodChannel(
      name: "timer/live_activity",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      // The views and the Stop intent live in the iOS 17 widget extension,
      // so below iOS 17 there is nothing to show.
      guard #available(iOS 17.0, *) else {
        result(nil)
        return
      }
      switch call.method {
      case "show":
        guard let state = contentState(from: call.arguments) else {
          result(
            FlutterError(
              code: "bad_args",
              message: "show needs sessionId, activityName and startedAtMs",
              details: nil
            )
          )
          return
        }
        Task { @MainActor in
          await show(state)
          result(nil)
        }
      case "end":
        Task { @MainActor in
          await endAll()
          result(nil)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    return channel
  }

  @available(iOS 17.0, *)
  private static func contentState(from arguments: Any?) -> TimerActivityAttributes.ContentState? {
    guard
      let args = arguments as? [String: Any],
      let sessionId = args["sessionId"] as? Int,
      let activityName = args["activityName"] as? String,
      let startedAtMs = args["startedAtMs"] as? Int
    else { return nil }
    return TimerActivityAttributes.ContentState(
      sessionId: sessionId,
      activityName: activityName,
      color: args["color"] as? Int,
      startedAt: Date(timeIntervalSince1970: Double(startedAtMs) / 1000)
    )
  }

  /// Updates the live activity in place, or starts one when none is live.
  @available(iOS 17.0, *)
  private static func show(_ state: TimerActivityAttributes.ContentState) async {
    let content = ActivityContent(state: state, staleDate: nil)
    let all = Activity<TimerActivityAttributes>.activities
    // iOS ends an activity itself after 8 hours but keeps it listed.
    let live = all.first { $0.activityState == .active || $0.activityState == .stale }
    for other in all where other.id != live?.id {
      await other.end(nil, dismissalPolicy: .immediate)
    }
    if let live {
      await live.update(content)
      return
    }
    // Turned off in Settings: nothing to do, and not an error.
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    // Local updates only, no push token.
    _ = try? Activity.request(
      attributes: TimerActivityAttributes(),
      content: content,
      pushType: nil
    )
  }

  @available(iOS 17.0, *)
  private static func endAll() async {
    for activity in Activity<TimerActivityAttributes>.activities {
      await activity.end(nil, dismissalPolicy: .immediate)
    }
  }
}
