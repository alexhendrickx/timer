# TimerWidget extension — source present, Xcode target not wired

`TimerWidget.swift` and `StartActivityIntent.swift` in this folder are the
real WidgetKit + App Intents source for the v0.5 widget tiles and the
Action button / Siri Shortcut. They are **not yet attached to an Xcode
target** — that step needs the Xcode GUI and cannot be done safely by
hand-editing `Runner.xcodeproj/project.pbxproj` (a malformed native-target
entry produces an unopenable project, and there's no `xcodebuild` dry-run
that validates a hand-written target the way the GUI's template does).

## What's done (headless, in this repo)
- `WidgetSnapshotWriter` (Dart) writes the JSON snapshot these Swift files
  read — tested in `test/core/widget_snapshot_writer_test.dart`.
- `AppGroupStorage` (Dart) + the `timer/app_group` method channel in
  `AppDelegate.swift` resolve the app-group container path.
- The `group.com.alexhendrickx.timer` app-group entitlement on the `Runner`
  target, confirmed to build and auto-sign for both the simulator and the
  connected physical iPhone.
- The widget + intent Swift source, ready to compile once added to a
  target.

## What needs Xcode + an Apple Developer account
1. Xcode → File → New → Target → **Widget Extension**, name it
   `TimerWidget`, uncheck "Include Configuration Intent" (this repo's
   intent is a separate App Intent, not a widget configuration intent).
2. Replace the generated `TimerWidget.swift` with this folder's version;
   add `StartActivityIntent.swift` to the new target.
3. In the new target's **Signing & Capabilities**, add the same App Group
   (`group.com.alexhendrickx.timer`) entitlement as `Runner`.
4. Confirm the widget extension is embedded in the main app's "Embed
   App Extensions" build phase (Xcode adds this automatically when the
   target is created from the app).
5. On a real device: both targets need a provisioning profile that
   includes the App Groups capability — Xcode's automatic signing usually
   handles this, but it has not been independently confirmed for a
   *second* (extension) target from this environment, only for `Runner`.

Until step 1 happens, `flutter build ios` / `flutter run` are unaffected —
there is no widget target to build, so nothing here is on the critical
path for the app itself. The gap is purely "no widget shows up on the
Home/Lock screen yet."
