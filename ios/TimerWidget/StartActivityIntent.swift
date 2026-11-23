import AppIntents

/// Backs the Action button Shortcut and the Siri Shortcut. Per the v0.5
/// validation (see the Task 1 commit message): this always opens the app —
/// `openAppWhenRun = true` — because starting a session must go through
/// Flutter's StartCoordinator so the D1 switch confirm is honored, and a
/// backgrounded App Intent has no UI to show that confirm. The intent opens
/// the app at `timer://quick-start`; Flutter's QuickStartIntentHandler
/// (lib/core/platform/ios/quick_start_intent_handler.dart) does the actual
/// start.
///
/// Note: `openAppWhenRun` only *foregrounds* the app — it does not deliver a
/// URL. The deep link is delivered by returning an `OpenURLIntent`, which
/// routes through `AppDelegate.application(open:)` → the `timer/deep_link`
/// channel → QuickStartIntentHandler.
struct StartActivityIntent: AppIntent {
  static var title: LocalizedStringResource = "Start Tracking"
  static var description = IntentDescription("Opens Timer's quick-start picker.")
  static var openAppWhenRun: Bool = true

  func perform() async throws -> some IntentResult & OpensIntent {
    return .result(opensIntent: OpenURLIntent(URL(string: "timer://quick-start")!))
  }
}

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
