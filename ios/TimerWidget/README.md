# TimerWidget extension

WidgetKit extension target (`be.alexhendrickx.timer.TimerWidget`, iOS 17+),
embedded in `Runner`. It reads `<app group>/activity_snapshot.json`, which
Flutter's `WidgetSnapshotWriter` writes; `AppDelegate` reloads timelines
after each write. Tiles link to `timer://quick-start?activityId=…`.

The Action button / Siri intent (`StartActivityIntent`, iOS 16+) lives in
`ios/Runner/StartActivityIntent.swift`, so it runs in the app process.

The target was added with the `xcodeproj` gem; its build version comes from
`TimerWidget.xcconfig` → `Flutter/Generated.xcconfig`, so it always matches
`Runner`.

Not yet checked: device signing of the extension (needs the ASC API key,
see `docs/RELEASE-CHECKLIST.md` A1).
