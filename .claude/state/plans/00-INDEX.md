# Build Index — Local Time Tracker (macOS)

Numbered build plans, one per app version. Run each in its own session, in
order. Each targets a `pubspec.yaml` version and ships working, testable
software on its own.

**Spec:** `docs/superpowers/specs/2026-10-31-local-time-tracker-design.md`

| # | Version | Plan | Ships |
|---|---------|------|-------|
| 01 | v0.1.0 | `01-v0.1.0-scaffold.md` | Running macOS app: theme, drift DB, chosen data folder, empty home + settings |
| 02 | v0.2.0 | `02-v0.2.0-core-tracker.md` | Activities CRUD, pick-activity→Start/Stop, live elapsed, persist + crash-resume |
| 03 | v0.3.0 | `03-v0.3.0-menu-bar.md` | Menu-bar icon with live title + popover (Start/Stop, quick note), window launch |
| 04 | v0.4.0 | `04-v0.4.0-reminders.md` | Break-reminder notifications (default 90/15) + Settings controls |
| 05 | v0.5.0 | `05-v0.5.0-history.md` | History list, filters, rounded totals + amounts, notes, re-tag, archive/delete |
| 06 | v0.6.0 | `06-v0.6.0-export.md` | CSV + HTML + PDF export, grouped by activity, optional per-activity files |
| 07 | v1.0.0 | `07-v1.0.0-polish.md` | App icon, end-to-end verification, optional code-sign |

Post-v1: v2.0.0 adds manual/retro session entry + editing start/end times (D3).

Each plan sets `version:` in `pubspec.yaml` as its first task and ends with the
app built and run on macOS.

---

## UI/UX + platform decisions (2026-11-01, from the design deck)

Decided interactively with Alex via the A/B/C design-deck Artifact. These
**supersede** earlier assumptions where they conflict; plans 03–07 below still
describe the old macOS-only shape and must be revised to match (see Follow-ups).

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

### Follow-ups (not yet planned)
1. Update project `CLAUDE.md`: macOS-only → cross-platform (iPhone + Mac).
2. Write a short cross-platform design spec before rewriting plans 03–07
   (iOS has no menu bar; quick-start differs per platform; packaging/entitlements
   differ). Then revise: 03 (menu bar → platform-adaptive shell + shortcut/
   hotkey quick-start), 04–07 as needed.
3. Rework the Home UI toward the focus-cards launcher (supersedes the v0.2.0
   dropdown + Start picker).

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
