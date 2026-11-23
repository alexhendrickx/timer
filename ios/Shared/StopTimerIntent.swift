import ActivityKit
import AppIntents
import Foundation

/// The stop request the Live Activity's Stop button leaves for Flutter in
/// the app group: `{"sessionId": 12, "endedAt": "2026-11-23T14:53:05.123Z"}`.
/// Flutter's `StopRequestApplier` closes that session at exactly `endedAt`
/// and deletes the file.
enum StopRequestFile {
  static let appGroupId = "group.be.alexhendrickx.timer"
  static let fileName = "stop_request.json"

  /// Set by AppDelegate in the app process: tells Flutter a request is
  /// waiting. Stays nil in the widget extension.
  static var onWritten: (() -> Void)?

  /// True when a request for `sessionId` is on disk afterwards.
  static func write(sessionId: Int, endedAt: Date) -> Bool {
    guard
      let container = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: appGroupId
      )
    else { return false }
    let url = container.appendingPathComponent(fileName)

    // A second tap for the same session must not move the first tap's time.
    if let data = try? Data(contentsOf: url),
      let pending = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      pending["sessionId"] as? Int == sessionId
    {
      return true
    }

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let request: [String: Any] = [
      "sessionId": sessionId,
      "endedAt": formatter.string(from: endedAt),
    ]
    guard let data = try? JSONSerialization.data(withJSONObject: request) else {
      return false
    }
    do {
      try data.write(to: url, options: .atomic)
      return true
    } catch {
      return false
    }
  }
}

/// The Live Activity's Stop button. Compiled into both targets: the widget
/// extension builds the button with it, and because it is a
/// LiveActivityIntent iOS runs `perform` in the app's process, starting the
/// app in the background if it has to.
@available(iOS 17.0, *)
struct StopTimerIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "Stop Tracking"
  static var isDiscoverable: Bool = false

  @Parameter(title: "Session")
  var sessionId: Int

  init() {}

  init(sessionId: Int) {
    self.sessionId = sessionId
  }

  func perform() async throws -> some IntentResult {
    // First line on purpose: this instant is the session's end time.
    let endedAt = Date()
    guard StopRequestFile.write(sessionId: sessionId, endedAt: endedAt) else {
      // Not recorded, so the Live Activity stays: the user can still stop
      // in the app.
      return .result()
    }
    // Only the activity that still shows this session.
    for activity in Activity<TimerActivityAttributes>.activities
    where activity.content.state.sessionId == sessionId {
      await activity.end(nil, dismissalPolicy: .immediate)
    }
    StopRequestFile.onWritten?()
    return .result()
  }
}
