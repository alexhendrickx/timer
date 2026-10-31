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
