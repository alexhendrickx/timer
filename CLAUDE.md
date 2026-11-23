# Project instructions — timer

A lightweight, **local-first**, **cross-platform** time tracker for **iPhone
and Mac** from one Flutter/Dart codebase. It records work sessions tagged by
activity/client, reminds you to take breaks, and exports clean reports. The
guiding goal: radically simple and fast — big buttons, one tap/one key to start,
no confirmation; quick-start via a global hotkey on Mac and a shortcut (Action
button / widgets / Siri) on iPhone. **Local-first**: data lives in a local SQLite
file (folder user-chosen on Mac) and the app works fully offline; it quietly
syncs the user's own data between their devices via their **Supabase** backend
(Sign in with Apple), single-user, no third-party sharing. Architecture mirrors the
`datewatch` Flutter app (feature-first `lib/core` + `lib/feature/*`, `provider`,
`go_router`, token-based `AppColors` + `buildAppTheme`). The UI is touch-first and
platform-adaptive (iPhone tiles / Mac full-width bars + menu bar).

Design: `docs/superpowers/specs/2026-11-02-cross-platform-redesign-design.md`.
Build plans: `.claude/state/plans/` (one per app version, run in order).

## Coding principles (always apply)

Before making **any** coding decision — choosing an approach, implementing,
editing, refactoring, or planning a change — apply the Karpathy coding
principles. In short:

1. **Think before coding.** State assumptions; if multiple interpretations
   exist, surface them instead of picking silently; if a simpler approach
   exists, say so; if something is unclear, stop and ask.
2. **Simplicity first.** Minimum code that solves the problem — no speculative
   features, no single-use abstractions, no unrequested configurability, no
   error handling for impossible cases.
3. **Surgical changes.** Touch only what the request requires; match existing
   style; don't refactor or reformat unrelated code; mention unrelated dead
   code rather than deleting it. Every changed line traces to the request.
4. **Goal-driven execution.** Turn tasks into verifiable success criteria
   (ideally a test), then loop until verified.

These merge with — and never override — the user's direct requests or the
global instructions in `~/.claude/CLAUDE.md`.

## Constraints

- Cross-platform targets: iPhone (iOS) and Mac (macOS) from one codebase.
  Networking is limited to the user's own Supabase project for sync
  (`supabase_flutter`); no Firebase, no analytics/tracking, no other network calls.
- Local-first: local SQLite is the source of truth; the app must work fully
  offline and sync is a background extra (never blocks start/stop).
- Never lose the exact recorded time — rounding is a view only.
- App version lives in `pubspec.yaml` as `version: x.y.z+build`.
