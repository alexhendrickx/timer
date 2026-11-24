import AppIntents
import UIKit

/// Backs the Action button Shortcut and the Siri Shortcut. Lives in the
/// Runner target so iOS runs it in-process. `openAppWhenRun` foregrounds the
/// app, then `perform` opens `timer://quick-start`, which routes through
/// `AppDelegate.application(open:)` to the `timer/deep_link` channel and
/// Flutter's QuickStartIntentHandler. Starting always goes through Flutter's
/// StartCoordinator so the switch confirm is honored.
@available(iOS 16.0, *)
struct StartActivityIntent: AppIntent {
  static var title: LocalizedStringResource = "Start Tracking"
  static var description = IntentDescription("Opens Timer's quick-start picker.")
  static var openAppWhenRun: Bool = true

  @MainActor
  func perform() async throws -> some IntentResult {
    await UIApplication.shared.open(URL(string: "timer://quick-start")!)
    return .result()
  }
}

@available(iOS 16.0, *)
struct TimerShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: StartActivityIntent(),
      phrases: ["Start tracking in \(.applicationName)"],
      shortTitle: "Start Tracking",
      systemImageName: "play.circle"
    )
  }
}
