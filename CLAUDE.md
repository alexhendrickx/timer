# Project instructions — timer

A lightweight, **fully on-device** macOS time tracker (Flutter/Dart). It records
work sessions tagged by activity/client, lives in the menu bar, reminds you to
take breaks, and exports clean reports. No cloud, no account, no network — data
lives in a local SQLite file whose folder the user chooses. Architecture mirrors
the `datewatch` Flutter app (feature-first `lib/core` + `lib/feature/*`,
`provider`, `go_router`, token-based `AppColors` + `buildAppTheme`).

Design: `docs/superpowers/specs/2026-10-31-local-time-tracker-design.md`.
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

- macOS desktop target only in v1; never add Firebase/http/network packages.
- Never lose the exact recorded time — rounding is a view only.
- App version lives in `pubspec.yaml` as `version: x.y.z+build`.
