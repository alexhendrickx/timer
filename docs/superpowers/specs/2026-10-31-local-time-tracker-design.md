# Design — Local Time Tracker (macOS)

Date: 2026-10-31
Author: Alex (with Claude)
Status: Draft for approval

## Intent and the why

Alex wants a lightweight, **fully on-device** time tracker for his Mac that
he can summon instantly (⌘+Space) and that lives in the top-right menu bar.
It records work sessions (date, start, end), tagged by an activity/client,
so he can see at a glance how long he has worked on specific things in his
life — in particular billable work for business clients. While a timer runs,
it reminds him (via a native notification) to take a break after a long-ish
focus block. He can browse past sessions, attach an optional note to each,
organise them, and export clean, readable documents (for invoicing and for
handing to clients). Displayed and exported totals are rounded to the nearest
half-hour so a 9h12m day reads as "9:00" and a 9h22m day reads as "9:30",
while the exact time is always preserved underneath.

The why: he does varied work (his own business, specific clients, personal
things) and wants frictionless logging plus an honest, readable picture of
where his hours go — without any cloud service holding his data.

## Goals

- Start/stop a timer in one or two clicks from the menu bar; it records
  `date`, `startTime`, `endTime`, `durationSeconds`.
- Every session is tagged with an **activity** (a named thing, e.g. a client
  or a personal category). Totals roll up per activity.
- **Workflow:** pick the activity from a list, then press Start.
- **Break reminders** while a timer runs: after a configurable work interval,
  fire a local notification suggesting a break of a configurable length.
  Default **90 min work / 15 min break**, changeable in Settings.
- **Menu bar presence** (top-right): an icon with a live-ticking elapsed time
  and current activity; a popover to Start/Stop and add a quick note; a link
  to open the full window.
- **History screen**: all past sessions, grouped/filterable by activity and
  date range, each showing raw and rounded duration, editable note.
- **Organise**: edit, delete, re-tag sessions; manage the activity list.
- **Export**: CSV + a clean printable **HTML** report + a formatted **PDF**
  report, grouped by activity, with rounded totals. CSV carries exact
  per-session durations; rounding appears on the roll-up totals.
- **Hourly rate (optional) per activity**: exports show amount = rounded hours
  × rate, with a grand total. Activities without a rate stay time-only.
- **Fully local**: no network, no account. Data in a local SQLite file whose
  containing folder the user can choose in Settings.
- Launchable via ⌘+Space (a normal macOS `.app`).

## Non-goals (v1)

- No cloud sync, accounts, auth, or multi-device (datewatch's Firebase stack
  is explicitly NOT carried over).
- No iOS/Android/Windows/Linux build in v1 (Flutter keeps them possible
  later; only macOS is built and verified now).
- No tax/VAT or currency-conversion logic. The only money math is
  rounded-hours × hourly-rate (see Decisions). Currency is a plain label.
- No manual / retro session entry in v1 — only live start/stop creates
  sessions. Editing a session's **note** is allowed; editing start/end times
  and adding past sessions by hand is **v2** (D3).
- No idle-detection / auto-pause when the Mac is idle in v1.
- No global system-wide hotkey to start/stop (⌘+Space launches the app via
  Spotlight; an in-app or global shortcut can come later).

## Anti-goals (would make this a failure even if it "works")

- Anything that sends Alex's time data off the device.
- Heavy, cluttered UI. It must feel as polished and calm as datewatch.
- Losing the exact recorded time — rounding is a *view*, never the stored
  truth.
- Friction at the moment of starting/stopping a timer.

## Constraints

- macOS desktop, built and run locally. Alex has an Apple developer account,
  so code-signing/notarization is available if needed later (not required to
  run locally).
- Must mirror the **datewatch architecture** (see below) so the result looks
  good and is maintainable in the same style.
- Work is to be delivered as **numbered, versioned build plans** that Alex can
  execute in separate sessions. App version lives in `pubspec.yaml`
  (`version: x.y.z+build`) and every plan states the version it targets.

## The "how" that is decided

### Stack
- **Flutter / Dart**, macOS desktop target. (Same framework as datewatch,
  which already builds macOS.)
- **State:** `provider`. **Routing:** `go_router`. (Same as datewatch.)
- **Local DB:** `drift` (SQLite) — typed queries, migrations, good for history
  and per-activity totals. DB file lives in a user-chosen folder (default
  `~/Documents/Timer/timer.sqlite`); the chosen path is persisted via
  `shared_preferences`.
- **Notifications:** `flutter_local_notifications` (macOS) for break reminders.
- **Menu bar / window:** `tray_manager` (top-right icon, live title, context
  menu) + `window_manager` (frameless popover + main window control).
- **Export:** CSV written directly; HTML report from a template; PDF via the
  `pdf` + `printing` packages. `path_provider` / `file_picker` for choosing
  the data folder and save locations. `share_plus`/`url_launcher` optional.
- **No Firebase, no `http`, no network packages.**

### Project structure (mirrors datewatch)
```
lib/
  core/
    theme/      app_theme.dart, app_colors.dart   (ported/adapted from datewatch)
    routing/    go_router config
    services/   db (drift), notifications, tray, storage-location, export
    widgets/    shared UI (pressable, etc.)
    utils/      duration rounding, formatting
  feature/
    tracker/    data (session, activity models + repo) · service (timer engine,
                reminder scheduler) · presentation (menu-bar popover, start/stop)
    history/    presentation (list, filters, edit/notes, organise)
    activities/ data + presentation (manage client/activity list)
    export/     service (csv/html/pdf) · presentation (export screen)
    settings/   presentation (reminder intervals, data-folder picker)
```

### Data model (v1)
- **Activity**: `id`, `name`, `color?`, `hourlyRate?`, `currencyLabel?`,
  `archived`, `createdAt`.
- **Session**: `id`, `activityId`, `date` (the day the session **started**),
  `startTime`, `endTime`, `durationSeconds`, `note?`, `lastSeenAt`,
  `createdAt`, `updatedAt`.
- Rounding helper: `roundToHalfHour(totalSeconds)` → nearest 1800s
  (`round(seconds / 1800) * 1800`). **Applied to roll-up totals only**
  (per activity, per period), never to the stored per-session value.
  Day-total examples: 9h12m (33120s) → 9h00; 9h22m (33720s) → 9h30.
- **Rounding aggregation = sum-then-round** (D4): sum exact session durations
  within a group, then round the total once. Individual sessions display exact.
- **Amount** (when `hourlyRate` set) = `roundedHours × hourlyRate`, computed on
  the rounded group total.

### Behaviour notes / Decisions
- **D1 — one timer at a time.** Starting a new timer while one runs prompts
  *"Client X is running. Stop it and start Client Y?"* (confirmed).
- **D2 — resume after quit/sleep.** While a timer runs, `lastSeenAt` is
  persisted periodically (e.g. every 30s). On reopen, if a session was still
  open, the app does **not** silently bill the gap — it asks: *"Timer for X has
  run since <start>. Keep going, or stop it at <lastSeenAt>?"* (builder's call,
  stated here).
- **D3 — no manual/retro entry in v1.** Only live start/stop creates sessions;
  session **notes** are editable. Add-by-hand + edit start/end times → v2.
- **D4 — rounding** = sum-then-round on totals (confirmed above).
- **D5 — midnight crossing.** A session belongs wholly to its **start day**; no
  splitting across days in v1 (builder's call, stated here).
- **D6 — export scope.** An export uses the currently-applied History filter
  (activity + date range), with an option to emit **one file per activity** for
  per-client invoicing (builder's call, stated here).
- **D7 — deleting an activity with sessions.** Not allowed; it is **archived**
  (hidden from the picker, history/totals preserved). Hard-delete only when the
  activity has zero sessions (builder's call, stated here).
- Break reminder is scheduled relative to the current session's start; after a
  break notification fires, the next is re-scheduled one interval later so
  reminders keep coming on long sessions.

### Versioning / delivery
- Written as numbered plans in `.claude/state/plans/NN-<slug>.md`, each
  targeting an app version:
  - **v0.1.0** — Scaffold: Flutter macOS app, datewatch-style theme/structure,
    drift DB, settings skeleton, data-folder picker. Runs with an empty home.
  - **v0.2.0** — Core tracker: activities CRUD, pick-activity→Start/Stop, live
    elapsed, sessions persisted, crash-resume.
  - **v0.3.0** — Menu bar: tray icon with live title + popover (Start/Stop,
    quick note), main window launch.
  - **v0.4.0** — Reminders: break-notification engine + Settings controls
    (default 90/15).
  - **v0.5.0** — History: list, filter by activity/date, edit notes, organise
    (re-tag, archive/delete per D7), per-activity rounded totals + amounts.
  - **v0.6.0** — Export: CSV + HTML + PDF, grouped by activity, rounded totals,
    optional per-activity files, hourly-rate amounts + grand total.
  - **v1.0.0** — Polish, icon, verification pass; optional code-sign.
  - **v2.0.0** (post-v1) — Manual/retro session entry + edit start/end times.
  Numbering/sequencing is finalised in the writing-plans step.

### Coding principles
- Carry over datewatch's `CLAUDE.md` Karpathy principles (think before coding,
  simplicity first, surgical changes, goal-driven) into this repo's CLAUDE.md.

## What is left to the builder

- Exact drift schema/migration code and repository method signatures.
- Precise theme values (ported from datewatch `app_colors.dart`/`app_theme.dart`).
- Tray popover layout specifics and window sizing.
- Notification copy and category/action wiring on macOS.
- HTML/PDF report visual layout (grouping, headers, totals placement).
- Test strategy per feature (rounding + repo logic are the obvious unit tests).

## Resolved with Alex

- **Money:** yes — optional hourly rate per activity; exports show amounts and
  a grand total (rounded hours × rate). No tax/VAT.
- **Two timers:** one at a time; starting a second asks to stop the first (D1).
- **Manual entry:** not in v1 — live start/stop only; notes editable; add/edit
  by hand deferred to v2 (D3).
- **Rounding:** sum real durations, round the total (D4).
- Builder's-call defaults D2, D5, D6, D7 above stand unless Alex objects.

No open questions remain.
```
