# Timer — TODO to ship (v1.0.0 built, all local)

## Git
- [ ] Push `feat/v1.0.0-polish` (= whole app) → PR into `main`

## Apple / Supabase setup
- [ ] Create iOS TimerWidget Xcode target (`ios/TimerWidget/README.md`)
- [ ] Enable Sign in with Apple: iOS + macOS App IDs + Xcode entitlements + Supabase Apple provider
- [ ] RLS second-user check in Supabase

## On-device QA
- [ ] Mac: hotkey+picker, menubar title, break overlay, notifications, D2 resume, charts, share-sheet, data-folder fallback
- [ ] iPhone: Action button/Siri, widget tile, long-press edit, break+notification, no double-timer, touch layout
- [ ] Sync round-trip on both devices (same Apple ID); offline→reconnect; signed-out = no network

## Optional / polish
- [ ] Fresh review of v1.0.0 diff (only self-reviewed)
- [ ] Code-sign + notarize for distribution

Details: `docs/RELEASE-CHECKLIST.md`.
