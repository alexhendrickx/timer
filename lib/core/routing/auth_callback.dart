/// Where Supabase sends the user back after an email-confirmation or
/// password-reset link. Must be listed under Supabase -> Authentication ->
/// URL Configuration -> Redirect URLs (docs/RELEASE-CHECKLIST.md A2b).
const String authCallbackUrl = 'timer://auth-callback';

/// True for any `timer://auth-callback...` link. The quick-start deep-link
/// handler ignores a link when this is true, whatever else it carries.
bool isAuthCallbackUri(Uri uri) =>
    uri.scheme == 'timer' && uri.host == 'auth-callback';

/// True only for `timer://auth-callback?code=...` with no `access_token`.
/// Supabase exchanges a link for a session only when this is true.
///
/// A `code` is useless without the PKCE verifier stored on this device. An
/// `access_token` is a ready-made session anyone could put in a link to sign
/// this device into their own account, so a link carrying one is refused.
bool isAuthCodeCallbackUri(Uri uri) {
  if (!isAuthCallbackUri(uri)) return false;
  try {
    final query = uri.queryParameters;
    final fragment = Uri.splitQueryString(uri.fragment);
    return query.containsKey('code') &&
        !query.containsKey('access_token') &&
        !fragment.containsKey('access_token');
  } on FormatException {
    // A malformed percent-escape (`%FF`) is not a link Supabase sent.
    return false;
  }
}
