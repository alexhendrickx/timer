import AppIntents

/// Backs the Action button Shortcut and the Siri Shortcut. Per the v0.5
/// validation (see the Task 1 commit message): this always opens the app —
/// `openAppWhenRun = true` — because starting a session must go through
/// Flutter's StartCoordinator so the D1 switch confirm is honored, and a
/// backgrounded App Intent has no UI to show that confirm. The intent itself
/// does nothing but open the app at `timer://quick-start`; Flutter's
/// QuickStartIntentHandler (lib/core/platform/ios/quick_start_intent_handler.dart)
/// does the actual start.
struct StartActivityIntent: AppIntent {
  static var title: LocalizedStringResource = "Start Tracking"
  static var description = IntentDescription("Opens Timer's quick-start picker.")
  static var openAppWhenRun: Bool = true

  func perform() async throws -> some IntentResult {
    // Opening the app at this URL is handled by the system because
    // openAppWhenRun is true; AppDelegate's deep-link handling (Task 5)
    // routes it to /quick-start. Nothing else to do here.
    return .result()
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
