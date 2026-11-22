# Timer v1.0.0 — Release Checklist

This is the single consolidated list of everything that **cannot be done
headlessly** and needs Alex, on a real Mac + iPhone with his Apple Developer
account, before shipping v1.0.0. It gathers the manual-QA items deferred
across v0.3.0–v0.9.0 plus the v1.0.0 cross-platform end-to-end script.

Everything that *could* be automated in this repo has been (see
"Automated gates" at the bottom — all green). The items below are the human
loop that no CI run can stand in for.

---

## A. One-time platform setup (blocks the device items below)

### A1. iOS widget / Action button / Siri Xcode target
Source is in `ios/TimerWidget/` (`TimerWidget.swift`, `StartActivityIntent.swift`)
but **not attached to an Xcode target** — that step needs the Xcode GUI.
Follow `ios/TimerWidget/README.md`:
1. Xcode → File → New → Target → **Widget Extension**, name `TimerWidget`,
   uncheck "Include Configuration Intent".
2. Replace the generated `TimerWidget.swift` with this repo's version; add
   `StartActivityIntent.swift` to the new target.
3. Add the App Group `group.be.alexhendrickx.timer` to the new target's
   Signing & Capabilities (same as `Runner`).
4. Confirm the extension is in the main app's "Embed App Extensions" phase.
5. On a real device confirm automatic signing provisions the *extension*
   target (only `Runner` has been confirmed from this environment).
Until this is done, `flutter build ios` is unaffected but no widget appears.

### A2. Sign in with Apple (native only, no Services ID or .p8)
The app signs in natively (`signInWithIdToken`), so Supabase needs only the
bundle id as a client ID. The entitlement is already in both `Runner` targets.
1. developer.apple.com → Identifiers → `be.alexhendrickx.timer` → tick
   **Sign in with Apple** (one App ID serves iOS and macOS).
2. Supabase dashboard (femmie) → Authentication → Providers → Apple → enable,
   **Client IDs** = `be.alexhendrickx.timer`. Leave the OAuth fields empty.

### A3. Supabase RLS second-user check
From `supabase-setup.md` §2.4. Schema + RLS are already applied live
(project `femmie`, ref `xftklvzkkbwwlbzbfysi`, security advisor 0 lints).
Still do it once before trusting real data: create a second throwaway auth
user, insert a row as each user, confirm a `select` under user B returns
only user B's rows.

---

## B. Mac on-device QA

- [ ] **B1. Global hotkey keypress** (v0.4 Task 6 / Review Focus): press the
  registered system-wide hotkey → Spotlight-style picker opens without
  raising the main window; type-to-filter; picking starts the timer. With a
  timer already running, a pick routes through the D1 switch confirm (never a
  silent switch). Close the main window, use the hotkey, reopen the window →
  engine state intact, title still ticking.
- [ ] **B2. Menu-bar title ticks** while a timer runs; the popover offers
  Start/Stop + quick note.
- [ ] **B3. Break overlay** fires at the set interval and re-arms for the next
  interval on a long session; dismiss by tap/swipe.
- [ ] **B4. Notification permission denied** (v0.6 Task 6): the app still
  tracks and still shows the in-app overlay when foregrounded; a one-time note
  appears; nothing is blocked.
- [ ] **B5. Resume after quit mid-run** (D2): quit with a timer running,
  relaunch → resume dialog offers keep-going vs stop-at-last-seen.
- [ ] **B6. Editing the running activity** (rename/recolor): running screen +
  card reflect it; the open session is untouched.
- [ ] **B7. Chart visual check** (v0.7): History day list → week bar chart →
  month heatmap render correctly; Reports ring/pie + figures read right;
  rated activity shows an amount, rate-less does not.
- [ ] **B8. Share-sheet export** (v0.8): export the current History filter to
  CSV + HTML + PDF, combined and per-activity, via the macOS share sheet;
  open each file; per-session CSV durations are exact, roll-up totals rounded.
- [ ] **B9. Data folder** (v0.1 / v1.0 Review Focus): change the data folder →
  relaunch reads from the new folder; point it at a missing folder → graceful
  fallback to `~/Documents/Timer` and the Home banner surfaces the reason.

## C. iPhone on-device QA (needs A1)

- [ ] **C1. Action button / Siri** (v0.5 Task 5): opens the app onto the
  picker; cold launch (process not running) reaches the picker, not a blank
  frame.
- [ ] **C2. Widget tile** one-tap start from the lock/home screen; launching
  from a tile while a different activity runs routes through the D1 confirm;
  empty/stale snapshot renders an "open app" tile, never a crash; tiles
  reflect today's totals.
- [ ] **C3. Long-press a card to edit; "+" to add** render in the touch layout.
- [ ] **C4. Break overlay / local notification** fires (foreground overlay;
  backgrounded → local notification).
- [ ] **C5. iOS backgrounding mid-session**: quick-start re-entry does not
  spawn a second timer; D2 resume governs a stale open session.
- [ ] **C6. History drill-down + Reports + share-sheet export** render in the
  touch layout; exported files open.

## D. Cross-device sync (needs A2 + A3)

- [ ] **D1. Sign in with Apple completes on macOS** (v0.9 validation flag) and
  on iPhone, yielding the same Supabase `user_id`.
- [ ] **D2. Round-trip**: create/edit a session on iPhone → appears on Mac and
  vice-versa within the debounce; a delete/archive on one propagates and is
  not resurrected on the next pull.
- [ ] **D3. Offline then reconnect**: keep tracking offline, come back online →
  queued changes drain; nothing lost or blocked meanwhile.
- [ ] **D4. Signed out**: with no sign-in the app makes zero network calls and
  behaves exactly as v0.8.

## E. Ship to TestFlight

One-time:
- [ ] **E1.** App Store Connect → Apps → **+** → New App, platforms iOS and
  macOS, bundle id `be.alexhendrickx.timer`, SKU `timer`.
- [ ] **E2.** Users and Access → Integrations → App Store Connect API →
  generate a key with role **App Manager**. Save the `.p8` to
  `~/.appstoreconnect/private_keys/`, then
  `cp config/release.env.example config/release.env` and fill in the key id,
  issuer id and path.
- [ ] **E3.** `config/dart_defines.json` holds the Supabase URL + publishable
  key (gitignored; copy from `config/dart_defines.example.json`).

Every release:
- [ ] `tool/release.sh ios` (or `macos`, `all`). It archives with the API key,
  lets Xcode create the App Store profiles, and uploads. Build number is the
  UTC timestamp. `DRY_RUN=1` exports locally without uploading.

---

## Automated gates (done headlessly in this repo — all green)

Run by the v1.0.0 build; see `docs/superpowers/verification/v1.0.0-e2e.md`
for the captured outputs.

- `flutter analyze` → 0 issues.
- `flutter test` → full suite green.
- `flutter build macos` → succeeds.
- `flutter build ios --simulator` → succeeds.
- App icon generated for iOS + macOS (`assets/images/app_icon.png`, applied
  via `flutter_launcher_icons`); version `1.0.0+10`.
- First-run guard: Home shows an actionable "Add your first activity" button
  (iPhone sheet / Mac Activities screen) and a dismissible data-folder
  fallback banner on Mac.
