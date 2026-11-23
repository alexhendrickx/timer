import ActivityKit
import Foundation

/// The Live Activity's data. Compiled into both Runner (which starts,
/// updates and ends it) and TimerWidget (which draws it), so the two always
/// agree on its shape. Everything is in ContentState because a switch to
/// another activity changes all of it in place.
@available(iOS 17.0, *)
struct TimerActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    /// Local database id of the running session. The Stop button sends it back.
    var sessionId: Int
    var activityName: String
    /// ARGB swatch as Flutter stores it (`Activity.color`), or nil.
    var color: Int?
    /// Session start. The views count up from it.
    var startedAt: Date
  }
}
