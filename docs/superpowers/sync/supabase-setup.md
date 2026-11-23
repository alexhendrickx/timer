# Supabase sync setup (v0.9.0)

The app's local SQLite file stays the source of truth. Sync is a fully
optional, background layer against **Alex's own Supabase project** — no
other cloud, and nothing in this doc is required for the app to work: with
no config, sync is disabled and the app behaves exactly like v0.8.

## 0. Live project (provisioned 2026-11-12)

The sync backend is **live**, sharing Alex's existing **`femmie`** Supabase
project (free tier; timer + femmie coexist — no table-name collision, femmie's
`public` only had `logs` / `key_material`).

- **Project ref:** `xftklvzkkbwwlbzbfysi` (region eu-central-1)
- **API URL:** `https://xftklvzkkbwwlbzbfysi.supabase.co`
- **Applied:** `supabase/sync.sql` → tables `public.activities` + `public.sessions`
  with RLS (4 policies each, `user_id = auth.uid()`). Security advisor: **0 lints**.
- **Publishable key:** supplied out-of-band via `--dart-define` (not committed here).

Still TODO (Alex): Sign in with Apple provider config (§3) + the on-device RLS
sanity check (§2.4).

## 1. Credentials: `--dart-define`, never committed

The app reads the Supabase URL and anon (publishable) key at compile time:

```dart
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
```

Both default to the empty string when not supplied. `lib/main.dart` only
initializes `supabase_flutter` when both are non-empty — an absent or
invalid config leaves the app purely local, with zero network calls.

Run / build with:

```bash
flutter run -d macos \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>

flutter build ios --simulator \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>
```

The anon key is safe to ship in a built app (it is public by design; Row
Level Security is what actually protects data — see `supabase/sync.sql`).
It is still kept out of version control here because the project ref/URL
is Alex's personal project, not something to hardcode into the repo.

For local day-to-day runs, put the two `--dart-define` values in a
git-ignored `.env.local` (or your IDE's run-configuration) and source them
into the command above — this repo does not commit any `.env*` file.

## 2. Applying `supabase/sync.sql`

1. Open the Supabase dashboard for the project → **SQL Editor**.
2. Paste the contents of `supabase/sync.sql` (repo root) and run it. It is
   idempotent (`create table if not exists`, `drop policy if exists` before
   each `create policy`) so re-running it is safe.
3. Confirm in **Authentication → Policies** that RLS is **enabled** on both
   `activities` and `sessions`, with four policies each (select/insert/
   update/delete) gated on `user_id = auth.uid()`.
4. **Needs Alex:** there is no live Supabase project reachable from this
   environment, so RLS has not been exercised against real data. After
   applying the SQL, verify it yourself: create a second throwaway auth
   user, insert a row as each user, and confirm a `select` under the
   second user's session returns only that user's row. `sync.sql`'s
   policies are written to guarantee this (`user_id = auth.uid()` on all
   four operations, enforced at the Postgres level), but "written to
   guarantee" is not the same as "observed working" — do this check once
   before trusting the project with real data.

Alternatively, via the Supabase CLI: `supabase db push --file supabase/sync.sql`
(or copy it into a numbered migration under `supabase/migrations/` if the
project already uses CLI-managed migrations).

## 3. Sign in with Apple — provider config

**Supabase side:**
1. Dashboard → **Authentication → Providers → Apple** → enable it.
2. Fill in the **Services ID**, **Team ID**, **Key ID**, and the private
   key (`.p8`) from the Apple Developer account's "Sign in with Apple"
   configuration (Certificates, Identifiers & Profiles → Keys).
3. Add the app's bundle id as an authorized client.

**Apple Developer account side (needs Alex — cannot be done from this
repo):**
1. Enable the **Sign in with Apple** capability for the iOS *and* macOS
   App IDs (two separate entitlements, same Apple ID flow).
2. Create a Services ID for the Supabase redirect (if using the OAuth
   web flow) — not required for the native `sign_in_with_apple` credential
   flow used here, which exchanges the device-signed Apple credential
   directly for a Supabase session via `signInWithIdToken`.
3. In Xcode, add the **Sign in with Apple** capability to both the
   `Runner` (iOS) and `Runner` (macOS) targets — this writes the
   `com.apple.developer.applesignin` entitlement into
   `ios/Runner/Runner.entitlements` and `macos/Runner/*.entitlements`.
   (Already done in this repo: macOS's `com.apple.security.network.client`
   entitlement, needed for the sandboxed app to reach Supabase at all —
   it only had `network.server` before v0.9.0.)

**Validation flag outcome (Task 1, Step 2):** the Dart-side flow
(`AuthService.signInWithApple`) is implemented identically for iOS and
macOS — `sign_in_with_apple` exposes the same `SignInWithApple.getAppleIDCredential`
API on both platforms, and the credential is exchanged for a Supabase
session the same way on both. **What still needs Alex, and cannot be
verified from this environment:** the Apple Developer "Sign in with Apple"
capability must be enabled for both the iOS and macOS App IDs, and the
Xcode entitlement added to both Runner targets (step 3 above) — without
it, the native call fails with `AuthorizationErrorCode.unknown` on both
platforms at runtime. This has not been exercised against a live Apple
Developer account or a live Supabase project from this session; the Dart
flow is implemented and unit-tested against a fake Supabase client (see
`test/feature/auth_service_test.dart`), but the on-device macOS run that
proves the entitlement + provider config end-to-end is Alex's to do.

## 4. What syncs

Only `activities` and `sessions`, scoped to the signed-in `user_id`. See
`supabase/sync.sql` for the exact schema and `lib/feature/sync/` for the
sync engine.
