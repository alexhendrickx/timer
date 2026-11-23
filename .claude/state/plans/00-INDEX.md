# Build Index — Cross-Platform Time Tracker (iPhone + Mac)

Numbered build plans, one per app version. Run each in its own session, in
order. Each targets a `pubspec.yaml` version and ships working, testable
software on its own.

**Spec:** `docs/superpowers/specs/2026-11-02-cross-platform-redesign-design.md`

| # | Version | Plan | Ships |
|---|---------|------|-------|
| 01 | v0.1.0 | `01-v0.1.0-scaffold.md` | Running app: theme, drift DB, chosen data folder, empty home + settings *(shipped)* |
| 02 | v0.2.0 | `02-v0.2.0-core-tracker.md` | Activities CRUD, pick-activity→Start/Stop, live elapsed, persist + crash-resume *(shipped)* |
| 03 | v0.3.0 | `03-v0.3.0-focus-home.md` | Focus-cards home launcher (ring + today total), one-tap instant start, Running screen, D1 switch confirm |
| 04 | v0.4.0 | `04-v0.4.0-platform-shell-mac.md` | PlatformShell seam + Mac menu-bar (live title, popover) + global-hotkey Spotlight picker |
| 05 | v0.5.0 | `05-v0.5.0-iphone-quickstart.md` | iPhone quick-start: Action button/Siri onto the picker + lock/home-screen widgets |
| 06 | v0.6.0 | `06-v0.6.0-activities-break.md` | Adaptive activity management (iPhone long-press/+, Mac screen) + full-screen break overlay (+ notification fallback) |
| 07 | v0.7.0 | `07-v0.7.0-history-reports.md` | History drill-down (day list → week bars → month heatmap) + Reports ring/pie with figures + amounts |
| 08 | v0.8.0 | `08-v0.8.0-export.md` | Share-sheet export (CSV/HTML/PDF, per-activity option) + view-only configurable rounding (15-min default) |
| 09 | v0.9.0 | `09-v0.9.0-sync.md` | Supabase local-first sync (RLS, LWW, soft-delete) + Sign in with Apple (iOS + macOS) |
| 10 | v1.0.0 | `10-v1.0.0-polish.md` | App icon (both platforms), cross-platform end-to-end verification, polish, optional code-sign |

Post-v1: v2.0.0 adds manual/retro session entry + editing start/end times (D3).

Each plan sets `version:` in `pubspec.yaml` as its first task and ends with the
app built and run on the relevant platform(s).

> **Note — v0.3.0 supersedes v0.2.0's home.** v0.2.0 shipped a dropdown-picker +
> Start home. v0.3.0 replaces it with the focus-cards launcher (one tap on a card
> starts that activity). The v0.2.0 `TimerEngine`, `SessionRepository`, and
> `ActivityRepository` carry over unchanged; only the Home presentation is
> rebuilt.

---

## UI/UX + platform decisions (2026-11-01, from the design deck)

Decided interactively with Alex via the A/B/C design-deck Artifact. These
**supersede** earlier assumptions where they conflict. They are now encoded in
the `2026-11-02-cross-platform-redesign-design.md` spec and in the rewritten
plans 03–10 above (the Follow-ups below are done).

- **Platform (deck R0 = C):** cross-platform — **iPhone + Mac from one Flutter
  codebase**, touch-first UI that scales. No longer macOS-only. ⚠️ This
  conflicts with the "macOS desktop target only in v1" line in the project
  `CLAUDE.md` — that line needs updating.
- **North-star — shortcut-driven instant start:** start the timer with a
  **global hotkey on Mac** and a **shortcut on iPhone** (Siri Shortcut / Action
  button / lock-screen widget / Control Center), ideally without opening the app.
  Speed above all: one key/tap and it counts, no confirmation.
- **Start screen = start control (deck R1/R2 merged):** the home screen IS the
  activity launcher. Chosen layout = **focus cards** — a 2-column grid of
  activity cards, each with a small progress ring + today's total; **one tap
  starts that activity immediately** (no separate picker, no confirm).
- **Running screen (deck R3):** large calm timer + current activity label + a
  single **red Stop button**. (Tap-anywhere-to-stop was considered and dropped —
  keep it simple for now.)
- **Button style, platform-adaptive (deck R4):** **iPhone = tiles**, **Mac =
  full-width bars**. Same app, styled per device. On Mac it also lives in the
  menu bar and starts via hotkey; on iPhone via shortcut / Action button.
- **Visual language:** iOS system colors (blue #0A84FF, green, red) over the
  existing `AppColors` tokens; big touch targets throughout.

### Follow-ups
1. ~~Write a cross-platform design spec~~ — done: `2026-11-02-cross-platform-redesign-design.md`.
2. ~~Rewrite plans 03–07 (+ add 08–10) to the cross-platform breakdown~~ — done (see table above).
3. ~~Rework Home toward the focus-cards launcher~~ — planned in v0.3.0 (supersedes v0.2.0 dropdown).
4. ~~Update the project `CLAUDE.md` "macOS desktop target only" constraint~~ —
   done on this branch: `CLAUDE.md` now reads cross-platform + local-first
   Supabase sync (commits `41ae0c3`, `c324509`).

## Quick-start & activity decisions (2026-11-02, deck 2)

- **Quick-start always opens a chooser** (consistent on both platforms), never
  blind-starts the last activity:
  - **Mac:** global hotkey opens a small Spotlight-style picker → pick → start.
  - **iPhone:** Action button opens the app straight onto the picker (tap one →
    starts) **and** lock/home-screen widgets with per-activity tiles.
- **Start while one runs:** ask first ("X loopt — stoppen en Y starten?") then
  switch. (Not silent-switch; D1 confirm stays.)
- **Activity management is platform-adaptive:** iPhone = long-press a card to
  edit, "+" to add; Mac = a dedicated Activities screen (name, color, hourly
  rate, archive).
- **Activity card shows today's total** (+ ring). Behind it: **drill-down
  day → week → month** — home is today; you navigate deeper for week and month.
  Everything stays recorded; nothing is ever discarded.

## Overview / reports / reminders decisions (2026-11-02, deck 3)

- **Break reminder = full-screen gentle overlay** ("Time to stand" style),
  easily dismissable; default interval editable. (Alex's call over the subtler
  options.)
- **History = drill-down:** day list (= home/today) → **week bar chart** →
  **month calendar heatmap**.
- **Per-activity totals = ring/pie chart with exact figures + amounts listed
  beside it** (visual + precise, not either/or).
- **Export via the system share sheet** (PDF / CSV / HTML) — works on iPhone and
  Mac.
- **Rounding default = 15 min**, a view-only layer; exact `durationSeconds` is
  always stored (never rounded in storage — see Anti-goals).
