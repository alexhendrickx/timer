# Timer — TODO to ship (v1.0.0 built, all local)

## Git
- [ ] Push `feat/v1.0.0-polish` (= whole app) → PR into `main`

## Apple / Supabase setup
- [ ] Create iOS TimerWidget Xcode target (`ios/TimerWidget/README.md`)
- [ ] Enable Sign in with Apple: tick it on the App ID + Supabase Apple provider client id (checklist A2)
- [ ] RLS second-user check in Supabase

## On-device QA
- [ ] Mac: hotkey+picker, menubar title, break overlay, notifications, D2 resume, charts, share-sheet, data-folder fallback
- [ ] iPhone: Action button/Siri, widget tile, long-press edit, break+notification, no double-timer, touch layout
- [ ] Sync round-trip on both devices (same Apple ID); offline→reconnect; signed-out = no network

## Optional / polish
- [ ] Fresh review of v1.0.0 diff (only self-reviewed)
- [ ] TestFlight: App Store Connect app record + API key, then `tool/release.sh all` (checklist E)
- [ ] Mac data folder: sandbox loses a user-picked folder after relaunch (no security-scoped bookmark)
- [ ] In-app account deletion (App Review 5.1.1(v)); femmie `auth.users` is shared, delete only timer rows + the user
- [ ] Replace placeholder iOS launch image

Details: `docs/RELEASE-CHECKLIST.md`.
