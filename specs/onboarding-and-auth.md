# Onboarding + sign-in (Apple, Google, email)

Branch: `feat/onboarding-and-auth`. Mockups (approved):
https://claude.ai/code/artifact/e3a8f1cd-c250-4309-99c6-0a820b97792b
(artboards Main, Sync, EmailSignIn, EmailSent, QuickStart).

## Goal

A first-run flow of 3 skippable steps that leaves a new user with activities,
optional sync, and a quick-start method. Sign-in offers Apple, Google and
email/password. Sync stays optional: skipping sign-in keeps the app fully
local, exactly as today.

## Behaviour

### First run
- Shown once, on first launch when the database has zero activities and the
  `onboarding_done` pref is unset. "Skip setup" or finishing sets the pref.
  Existing users (who already have activities) never see it.
- Step 1, activities: preset list (Client work, Meetings, Admin, Deep focus,
  Learning; first two preselected), each with a distinct preset color from
  the existing activity palette, plus "+ Add your own" (reuses the existing
  add-activity sheet/dialog). Continue creates the selected activities via
  `ActivityRepository`. Continue is disabled with 0 selected.
- Step 2, sync: only shown when Supabase is configured (`AuthService` non-null).
  Buttons: Sign in with Apple, Sign in with Google (hidden when Google client
  ids are not configured), Continue with email, "Not now". Success → step 3.
- Step 3, quick start: iPhone shows Action button / widget / Siri rows with
  short instructions (static guidance, no system API calls); Mac shows the
  ⌘⇧Space hotkey. Done → Home.
- Layout: iPhone full-screen pages with progress bar; Mac the same content in
  the main window, max width ~480 centered. Big touch targets (≥56 px buttons).

### Sign-in methods (all end in a Supabase session; `AuthService` stays the single entry)
- **Apple**: unchanged native flow. Add a hashed nonce (raw nonce to Supabase,
  SHA-256 to Apple) — standard Supabase pattern.
- **Google**: native `google_sign_in` (iOS + macOS) → idToken →
  `signInWithIdToken(provider: google, idToken, accessToken)`. Client ids via
  `--dart-define` `GOOGLE_IOS_CLIENT_ID` and `GOOGLE_WEB_CLIENT_ID`
  (serverClientId); absent → Google button hidden. iOS Info.plist needs
  `GIDClientID` and the reversed client id URL scheme; read them from
  build settings so no id is hard-coded in the repo.
- **Email/password**: one screen with a Sign in / Create account segmented
  control (mockup EmailSignIn). Use `AutofillGroup` + `autofillHints`
  (`email`, `password` / `newPassword`) so iOS/macOS Keychain suggests and
  saves passwords. Min 8 chars on create.
  - Create account → `signUp(email, password, emailRedirectTo: 'timer://auth-callback')`.
    With confirmation on, no session returns → show "Check your email" (mockup
    EmailSent): "Open Mail" (launch `message://` on iOS / Mail on macOS via
    url_launcher if available, else hide), Resend with 60 s cooldown.
  - Sign in → `signInWithPassword`. Map Supabase errors to plain text:
    invalid credentials, email not confirmed (offer resend), rate limited,
    offline ("No connection. Your timer still works offline.").
  - Forgot password → `resetPasswordForEmail(redirectTo: 'timer://auth-callback')`
    → "Check your email". On the deep link with a recovery session
    (`AuthChangeEvent.passwordRecovery`), show a "Set new password" screen →
    `updateUser(password)`.
- Deep link `timer://auth-callback` must work on iOS (scheme exists) and macOS
  (add `CFBundleURLTypes` with `timer`). Let supabase_flutter handle the
  session from the URL (PKCE); make sure it does not collide with the existing
  quick-start deep-link handler (`test/core/deep_link_test.dart`).

### Settings
- The existing sync section offers the same three methods when signed out and
  shows the signed-in email + Sign out when signed in.

## Non-goals (separate branches)
- Account deletion (blocked on shared femmie `auth.users`; needs a design).
- Live Activity, widget target, Calendar, Mac auto-pause.
- Resend SMTP + Google Cloud OAuth client setup (Alex, dashboard steps; document
  them in `docs/RELEASE-CHECKLIST.md` A2b/A2c).

## Constraints
- Local-first: no network call when signed out; sign-in failures never block
  tracking.
- Never store passwords locally; the Keychain via autofill is the OS's job.
- No new network hosts beyond Supabase, Apple and Google sign-in.
- English UI copy, short.

## Acceptance
- `flutter analyze` clean, full `flutter test` green.
- New tests: onboarding shows only on first run; preset selection creates
  activities; skip sets pref; step 2 hidden without AuthService; Google button
  hidden without client ids; AuthService email sign-up/sign-in/reset paths
  against a fake backend incl. error mapping; nonce is hashed for Apple.
- `flutter build ios --simulator` and `flutter build macos` succeed.
