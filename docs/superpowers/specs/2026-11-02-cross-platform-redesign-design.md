# Design — Cross-Platform Time Tracker (iPhone + Mac)

Date: 2026-11-02
Author: Alex (with Claude)
Status: Draft for approval
Supersedes: `2026-10-31-local-time-tracker-design.md` (macOS-only) where they conflict.

This spec carries over the still-valid substance of the original macOS design
(data model, decisions D1–D7, anti-goals, rounding rules) and supersedes
everything that assumed a macOS-only, menu-bar-first app. It encodes the
interactive decisions recorded in `.claude/state/plans/00-INDEX.md`
(2026-11-01 deck 1, 2026-11-02 decks 2 and 3), which are authoritative.

## Intent and the why

A lightweight, **local-first** time tracker Alex can run on **both his
iPhone and his Mac from one Flutter codebase**, with his sessions **quietly
syncing between the two devices** through his own Supabase backend. It records work sessions
(date, start, end), each tagged by an activity/client, so he can see at a
glance how long he has worked on specific things — in particular billable work
for business clients. While a timer runs, it gently reminds him to take a
break. He can browse past sessions, attach notes, organise them, and export
clean, readable reports (CSV / HTML / PDF) for invoicing. Displayed and
exported totals are rounded (default 15 min), while the exact recorded time is
always preserved underneath.

**The blue-whale goal — radically simpler and faster than the market.** The
single thing this app must beat every competitor at is the *moment of starting*.
On Mac a global hotkey, on iPhone the Action button / a widget / Siri — ideally
without even opening the app. One key or one tap and it is counting. No account,
no setup ritual, no multi-step "new entry" form. Everything else (history,
reports, rates) exists to serve that one honest, frictionless loop.

## Goals

- Start/stop a timer in **one tap or one key**, tagged with an activity, on
  both platforms. Records `date`, `startTime`, `endTime`, `durationSeconds`.
- **Home screen is the start control:** a 2-column grid of **focus cards**, one
  per activity, each with a small progress ring + today's total. One tap on a
  card starts that activity immediately.
- **Shortcut-driven quick-start from outside the app:** global hotkey on Mac
  (Spotlight-style picker), Action button / lock- & home-screen widgets / Siri
  on iPhone. Always opens a chooser (never blind-starts the last activity).
- **Running screen:** large calm timer + current activity label + a single red
  Stop button.
- **Break reminders** while a timer runs: a full-screen, gentle, easily
  dismissable overlay ("Time to stand" style). Default interval editable in
  Settings.
- **History drill-down:** today's day list (= home context) → week bar chart →
  month calendar heatmap. Everything stays recorded; nothing is discarded.
- **Per-activity totals:** a ring/pie chart shown *with* exact figures and
  amounts listed beside it (visual and precise, not either/or).
- **Export via the system share sheet** — CSV + clean HTML + formatted PDF,
  grouped by activity, with rounded totals. Works on iPhone and Mac.
- **Optional hourly rate per activity:** exports show amount = rounded hours ×
  rate, with a grand total. Rate-less activities stay time-only.
- **Local-first with quiet sync:** the local SQLite file is the source of truth
  and the app works fully offline; `activities` and `sessions` sync in the
  background across the user's own devices via **Supabase** (Sign in with Apple).
  Signing in is optional — without it the app is purely local. Mac DB folder is
  user-chosen; iPhone uses the app container (see Data model).
- **Platform-adaptive UI:** touch-first, big targets everywhere; iPhone =
  tiles, Mac = full-width bars + menu-bar presence + hotkey.

## Non-goals (v1)

- No *collaboration / multi-user* features — sync is single-user (Alex's own
  devices) only; no sharing, teams, or public data. (Cross-device sync itself is
  now in scope via Supabase — see Sync.)
- No Android / Windows / Linux build (Flutter keeps them possible later).
- No tax/VAT or currency conversion. Money math is only rounded-hours × rate;
  currency is a plain label.
- No manual / retro session entry in v1 — only live start/stop creates
  sessions. Session **notes** are editable; editing start/end times and adding
  past sessions by hand is **v2** (D3).
- No idle-detection / auto-pause in v1.

## Anti-goals (a failure even if it "works")

- **Losing the exact recorded time.** Rounding is a *view* only, never the
  stored truth. `durationSeconds` is always exact.
- Sending Alex's data to any third party. It lives only in his own Supabase
  project; no analytics, tracking, or ads. Networking is limited to that sync.
- **Friction at the moment of starting/stopping.** A slow, multi-step start is
  a failure. One tap / one key, no confirmation (except the single running-timer
  switch confirm, D1).
- Heavy, cluttered UI. It must feel as calm and polished as datewatch.

## Platforms and architecture

**One Flutter/Dart codebase, two targets: iOS (iPhone) and macOS (Mac).**
Touch-first, platform-adaptive UI. State via `provider`, routing via
`go_router`, theme via token-based `AppColors` + `buildAppTheme`
(datewatch-style).

The split is **shared logic vs. platform shell**:

- **Platform-agnostic core (identical on both):**
  - `TimerEngine` — single source of truth for the running session: start, stop,
    switch, live elapsed ticking, `lastSeenAt` persistence and crash/sleep
    resume (D2).
  - **Repositories** over a `drift` SQLite DB — activities, sessions, totals,
    history queries, rounding roll-ups.
  - Pure utilities — rounding (`roundToNearest(totalSeconds, stepSeconds)`),
    duration/amount formatting, date-grouping (day/week/month).
  - Reminder scheduling logic (when the next break is due).
  These modules **must not import** `dart:io` platform branches or any
  platform-UI package; they are unit-testable and shared verbatim.

- **Platform shell (branches per platform):**
  - **Mac:** app window + **menu-bar presence** (live-ticking title, popover with
    Start/Stop + quick note, link to open the window) + **global hotkey** that
    opens a Spotlight-style picker. Full-width bar button style. Data folder is
    user-chosen (file picker).
  - **iPhone:** no menu bar (iOS has none — note this explicitly). Tile button
    style. Quick-start via **Action button / widgets / Siri Shortcut**. Break
    overlay and share-sheet export are the iOS-native equivalents. Data lives in
    the app container (no folder picker; see Data model).

  Shell branching is chosen at a single seam — e.g. a `PlatformShell`
  abstraction resolved via DI (as the existing app shell already uses DI/
  routing) — so screens request capabilities ("register quick-start",
  "show menu-bar title") and the Mac/iOS implementation is injected. Keep the
  branch count small and at the edges; screens and core stay platform-free.

**Reused from current code:** the existing DI + routing + theme-token shell
(v0.1.0) and the drift schema (activities, sessions) carry over. The macOS
menu-bar/window work (`tray_manager` / `window_manager`) stays Mac-only behind
the shell seam.

## Screens

All screens are one responsive Flutter tree; the button-style and chrome
differences are platform-adaptive, not separate screens.

### Home — focus-cards launcher (the start control)
- A 2-column grid of activity cards. Each card: activity name + color, a small
  **progress ring**, and **today's total** for that activity.
- **One tap on a card starts that activity immediately** — no picker step, no
  confirm (unless a timer is already running → D1 switch confirm).
- iPhone: tile cards; long-press a card to edit it; a "+" affordance adds a new
  activity. Mac: card grid too, but activity *management* lives on its own
  screen (below); cards use the Mac bar/press styling.
- Home shows **today**. Drilling into a card (or the history entry point) goes
  deeper: day → week → month.

### Running
- Shown while a timer runs. Large, calm, live-ticking timer; the current
  activity label; a single **red Stop button**. Nothing else competing for
  attention. (Tap-anywhere-to-stop was considered and dropped — keep it simple.)
- On Mac this state is also reflected in the menu-bar title and popover.

### Activity management (platform-adaptive)
- **iPhone:** inline — **long-press a card to edit**, **"+" to add**. Edit sheet:
  name, color, hourly rate (optional), archive.
- **Mac:** a **dedicated Activities screen** listing all activities with name,
  color, hourly rate, and archive controls.
- Deleting an activity that has sessions is not allowed — it is **archived**
  (hidden from the launcher; history/totals preserved). Hard-delete only when
  it has zero sessions (D7).

### History — drill-down
- **Day list** (the home/today context): sessions for a day, each with exact
  duration and editable note; the day's rounded roll-up total.
- **Week bar chart:** one bar per day for the selected week.
- **Month calendar heatmap:** days shaded by tracked time.
- Navigation is top-down: today → week → month. Filter by activity and date
  range feeds both the views and export scope (D6).

### Reports / totals
- **Per-activity totals as a ring/pie chart** for the selected period, shown
  **with exact figures and amounts listed beside it** — the visual and the
  precise numbers together. Amounts appear for activities with an hourly rate
  (rounded hours × rate), with a grand total.

### Settings
- Break-reminder interval (default editable), rounding step (default 15 min,
  view-only), data-folder picker (**Mac only**), hourly-rate/currency defaults
  if useful, and app info. iOS omits the folder picker.

## Quick-start

The consistent model on both platforms: **quick-start always opens a chooser**;
it never blind-starts the last activity. Pick one → it starts.

- **Mac:** a registered **global hotkey** opens a small **Spotlight-style
  picker** (a light, centered overlay listing activities, type-to-filter) → pick
  → start, without bringing up the main window. The menu-bar popover offers the
  same Start/Stop.
- **iPhone:** the **Action button** (and Siri Shortcut) opens the app **straight
  onto the picker** (the focus-cards launcher acts as that chooser) — tap one and
  it starts. **Lock- and home-screen widgets** show per-activity tiles for
  one-tap start from outside the app.
- **Switching while a timer runs (D1):** starting activity Y while X runs
  **asks first** — "X is running — stop it and start Y?" — then stops X and
  starts Y. This single confirm is the one intentional exception to the
  no-confirmation rule; the normal cold start has no confirm.

## Reminders, export, rounding

- **Break reminder = full-screen gentle overlay** ("Time to stand" style),
  easily dismissable (tap/swipe). Scheduled relative to the current session's
  start; after one fires, the next is re-scheduled one interval later so long
  sessions keep getting nudged. Default interval editable in Settings. On iPhone
  this is the in-app overlay (plus a local notification if the app is
  backgrounded); on Mac the overlay plus optional menu-bar/notification cue.
- **Export via the system share sheet** — CSV, clean printable HTML, and
  formatted PDF, grouped by activity with rounded totals; CSV carries exact
  per-session durations. Share sheet works natively on both iPhone and Mac.
  Export scope follows the currently-applied History filter, with an option to
  emit **one file per activity** for per-client invoicing (D6).
- **Rounding** — default **15 min**, a **view-only** layer applied to roll-up
  totals (per activity, per period) via **sum-then-round** (D4): sum the exact
  session durations in a group, then round the total once. Individual sessions
  always display exact. The stored `durationSeconds` is never rounded.
  Amount = rounded-hours × hourly-rate on the rounded group total.

## Sync (Supabase)

The app is **local-first**: the on-device SQLite DB is the source of truth and
every action works offline and instantly. Sync is an additive background layer
that keeps Alex's devices in agreement.

- **Backend:** the user's own **Supabase** project (Postgres + Auth), accessed
  via `supabase_flutter`. No other cloud.
- **Identity:** **Sign in with Apple** on both iPhone and Mac → the same Supabase
  `user_id`. Sign-in is required only to *enable* sync; the app is fully usable
  without ever signing in (then it is purely local).
- **What syncs:** `activities` and `sessions` rows, each scoped to the signed-in
  `user_id`. **Row-Level Security** (`user_id = auth.uid()`) guarantees a user
  only ever reads/writes their own rows.
- **Direction & timing:** background and debounced ("quiet"). On local change and
  on reconnect: push local changes up, pull remote changes down. The live timer
  stays driven by the local `TimerEngine`; a running session may sync its
  `lastSeenAt` as it ticks, but local remains authoritative for the live count.
- **Conflict resolution:** single-user, so **last-write-wins per row** on an
  `updatedAt` timestamp. Simple and sufficient — no merge UI. A closed session is
  immutable except its note (also LWW).
- **Offline:** every write hits local SQLite first and is queued; the queue
  drains when a connection and a signed-in session are available. Losing network
  never blocks start/stop.
- **Deletes / archive:** archive and D7 hard-delete propagate via a soft-delete
  flag (`deletedAt`) so a delete on one device removes the row on the other and
  is not resurrected on the next pull.

## Data model (carried over, cross-platform notes added)

Unchanged from the original spec except where cross-platform matters.

- **Activity:** `id`, `name`, `color?`, `hourlyRate?`, `currencyLabel?`,
  `archived`, `createdAt`.
- **Session:** `id`, `activityId`, `date` (the day the session **started**),
  `startTime`, `endTime`, `durationSeconds` (exact), `note?`, `lastSeenAt`,
  `createdAt`, `updatedAt`.
- **Rounding helper** applied to roll-up totals only, never to stored
  per-session values. Default step 15 min (900s) — generalise the original
  half-hour helper to a configurable step: `round(seconds / step) * step`.
- **Aggregation = sum-then-round (D4).**
- **Amount** (when `hourlyRate` set) = rounded-hours × rate on the group total.

Decisions that still hold verbatim:

- **D1 — one timer at a time.** Starting a second asks to stop the first, then
  switches (see Quick-start switching flow).
- **D2 — resume after quit/sleep.** `lastSeenAt` persisted periodically while
  running; on reopen an open session is not silently billed — the app asks to
  keep going or stop it at `lastSeenAt`. Applies on both platforms (iOS
  background/termination makes this *more* important than on Mac).
- **D3 — no manual/retro entry in v1** (notes editable; add/edit times → v2).
- **D4 — rounding = sum-then-round.**
- **D5 — midnight crossing.** A session belongs wholly to its **start day**; no
  splitting across days in v1.
- **D7 — delete-with-sessions = archive, not delete.**

**Cross-platform data note:** each install keeps its own local drift SQLite DB
as the source of truth; the two are kept in agreement by background Supabase
sync (see Sync), not by sharing a file. Sync adds `updatedAt` / `deletedAt`
bookkeeping and a `user_id` association used only when signed in. On **Mac** the
DB file lives in a user-chosen folder
(default `~/Documents/Timer/timer.sqlite`, path persisted via
`shared_preferences`). On **iPhone** the DB lives in the app's documents
container (iOS has no user-visible folder picker and sandboxes file access);
the Settings folder-picker is Mac-only. The drift schema and repositories are
identical across both.

## Constraints (from CLAUDE.md)

- **Cross-platform targets: iPhone (iOS) and Mac (macOS) from one codebase.**
  Networking is limited to the user's own Supabase project for sync (via
  `supabase_flutter`); no Firebase, no analytics/tracking, no other network calls.
- Never lose the exact recorded time — rounding is a view only.
- App version lives in `pubspec.yaml` as `version: x.y.z+build`.
- Mirror the datewatch architecture (feature-first `lib/core` + `lib/feature/*`,
  `provider`, `go_router`, token-based `AppColors` + `buildAppTheme`).
- Apply the Karpathy coding principles on every decision (think before coding,
  simplicity first, surgical changes, goal-driven).

## Left to the builder

Settle these with normal engineering judgement; only the flagged items need
Alex.

- Exact drift schema deltas/migrations and repository method signatures
  (extend the existing v0.1.0 schema; add the configurable rounding step).
- The `PlatformShell` / capability-seam API shape and how Mac vs iOS
  implementations are registered in DI.
- Precise theme values: iOS system colors (blue `#0A84FF`, green, red) layered
  over the existing `AppColors` tokens; focus-card, ring, and bar/tile specs.
- Focus-card grid details (card size, ring thickness, empty/zero-today state),
  running-screen layout, Spotlight-picker overlay visuals, break-overlay copy
  and animation.
- History chart specifics (week bar chart, month heatmap shading scale) and the
  ring/pie + figures layout on the Reports screen — reuse the `dataviz` guidance.
- HTML/PDF report visual layout and the per-activity-file export packaging.
- Test strategy per feature — rounding, aggregation, TimerEngine state machine,
  and resume (D2) are the obvious unit tests and must be platform-free.

**Flag for Alex / validate during the relevant version plan (genuinely
platform-specific unknowns):**

- **iOS quick-start capability** — exactly what the Action button, lock/
  home-screen widgets, Siri Shortcut, and App Intents can do, and how much
  "start without opening the app" is actually achievable vs. "open onto the
  picker". Validate before committing the iOS quick-start plan. Widgets likely
  need a small native (WidgetKit/App Intents) extension that talks to the shared
  DB — confirm feasibility and the app-group/data-access approach.
- **macOS global-hotkey package choice** — which package registers a true
  system-wide hotkey for the Spotlight-style picker (e.g. a
  `hotkey_manager`-style package) alongside the existing `tray_manager` /
  `window_manager`. Validate it coexists with the menu-bar window.
- **Break reminder outside the app** — iOS backgrounding means the full-screen
  overlay can only show when the app is foreground; decide the local-notification
  fallback. Confirm `flutter_local_notifications` covers both iOS and macOS as
  needed.
- **Supabase sync** (in scope, best built as its own version so it does not block
  the local-first features): the Supabase table schema mirroring `activities` /
  `sessions`, RLS policies (`user_id = auth.uid()`), the local↔remote sync engine
  (change queue, debounce, last-write-wins on `updatedAt`, soft-delete via
  `deletedAt`), and the **Sign in with Apple** flow on both iOS and macOS (Apple
  Developer entitlement + Supabase Apple provider config). Validate that Sign in
  with Apple works on macOS as well as iOS.

