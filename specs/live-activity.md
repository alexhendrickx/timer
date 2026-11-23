# Live Activity + Dynamic Island (iPhone)

Branch: `feat/live-activity`, stacked on `feat/ios-widget-target` (needs the
`TimerWidget` extension). Mockup (approved): artboard "Live Activity +
widgets" in https://claude.ai/code/artifact/e3a8f1cd-c250-4309-99c6-0a820b97792b

## Goal

While a session runs on iPhone, the lock screen and Dynamic Island show the
activity name and a live elapsed timer, with a Stop button that works
without opening the app.

## Behaviour

- Session starts (any path: home, picker, widget, Siri, sync not involved)
  → start a Live Activity. Switch to another activity → update it (name,
  start time). Session stops (in app or from the Live Activity) → end it
  immediately (`.immediate` dismissal).
- Lock screen view: colored dot, "Tracking", activity name, elapsed time as
  a system timer text (`Text(timerInterval:)` / `Text(date, style: .timer)`),
  round Stop button. Dynamic Island: compact = dot + timer; minimal = dot;
  expanded = name, timer, Stop. Use system styles, no custom fonts.
- Stop button = a `LiveActivityIntent` (iOS 17+). It runs in the app
  process. The exact tap time is the session's end time; the recorded time
  must never be lost or shifted:
  - Write a stop request `{ "sessionId": <id>, "endedAt": <ISO-8601 UTC> }`
    to the app group (`stop_request.json`), end the Live Activity, and, if
    the Flutter engine is running, notify Dart over a method channel.
  - Dart applies a pending stop request (on that notify, on app start, and
    on resume) through the existing `TimerEngine` stop path with the given
    `endedAt`, only if that session is still the running one; then deletes
    the file. A request for a session that is no longer running is
    discarded.
- Cold start or app killed: the Live Activity outlives the app; on next
  launch, if no session is running, end any stale Live Activities.
- Not on macOS. Not on iOS < 17 (no-op; the Stop intent and `Button(intent:)` need iOS 17). Users who disabled Live
  Activities in Settings: no-op, no error.

## Constraints

- Local-first, no push notifications / APNs, no new network calls.
- Local updates only (`Activity.request(..., pushType: nil)`).
- `NSSupportsLiveActivities = YES` in Runner Info.plist.
- The `ActivityAttributes` type must be compiled into both Runner and the
  TimerWidget extension (shared Swift file in both targets via the
  `xcodeproj` gem, same approach as the widget target).
- Keep `TimerEngine` the single source of truth; the Live Activity only
  mirrors it. Stop with an explicit end time must reuse the engine's stop
  logic, not duplicate it.

## Acceptance

- `flutter analyze` clean, full `flutter test` green.
- Dart tests: engine start/switch/stop calls the Live Activity bridge with
  the right payloads (fake bridge); a pending stop request ends the matching
  running session at exactly `endedAt`; a request for another or no session
  is discarded and deleted; malformed file is ignored and deleted.
- `flutter build ios --simulator` succeeds, `Runner.app/PlugIns/TimerWidget.appex`
  present; `flutter build macos` unaffected.
