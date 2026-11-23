import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

enum AuthFailureKind {
  cancelled,
  invalidCredentials,
  emailNotConfirmed,
  rateLimited,
  offline,
  emailTaken,
  weakPassword,
  invalidEmail,
  unknown,
}

/// The only error AuthService lets out. [message] is one of nine fixed
/// strings, so no server or SDK text ever reaches the UI.
class AuthFailure implements Exception {
  const AuthFailure(this.kind);

  final AuthFailureKind kind;

  String get message => switch (kind) {
        AuthFailureKind.cancelled => '',
        AuthFailureKind.invalidCredentials => 'Wrong email or password.',
        AuthFailureKind.emailNotConfirmed =>
          'Confirm your email first. Check your inbox.',
        AuthFailureKind.rateLimited =>
          'Too many attempts. Wait a minute and try again.',
        AuthFailureKind.offline =>
          'No connection. Your timer still works offline.',
        AuthFailureKind.emailTaken =>
          'That email already has an account. Sign in instead.',
        AuthFailureKind.weakPassword =>
          'Use a stronger password with at least 8 characters.',
        AuthFailureKind.invalidEmail => 'Enter a valid email address.',
        AuthFailureKind.unknown => 'Something went wrong. Try again.',
      };

  @override
  String toString() => 'AuthFailure(${kind.name})';
}

/// Thrown by a credential getter when the user closes the Apple or Google
/// sheet. The UI shows nothing for it.
class AuthCancelled implements Exception {
  const AuthCancelled();
}

/// Maps anything a sign-in path can throw to an [AuthFailure].
AuthFailure mapAuthError(Object error) {
  if (error is AuthFailure) return error;
  if (error is AuthCancelled) {
    return const AuthFailure(AuthFailureKind.cancelled);
  }
  if (error is supabase.AuthException) {
    final code = error.code;
    final status = error.statusCode;
    final message = error.message.toLowerCase();
    // gotrue wraps a failed fetch (no response at all) in this type with no
    // status; with a status it is a 5xx from the server.
    if (error is supabase.AuthRetryableFetchException && status == null) {
      return const AuthFailure(AuthFailureKind.offline);
    }
    if (code == 'invalid_credentials' ||
        message.contains('invalid login credentials')) {
      return const AuthFailure(AuthFailureKind.invalidCredentials);
    }
    if (code == 'email_not_confirmed' ||
        message.contains('email not confirmed')) {
      return const AuthFailure(AuthFailureKind.emailNotConfirmed);
    }
    if (status == '429' ||
        code == 'over_request_rate_limit' ||
        code == 'over_email_send_rate_limit') {
      return const AuthFailure(AuthFailureKind.rateLimited);
    }
    if (code == 'user_already_exists' || code == 'email_exists') {
      return const AuthFailure(AuthFailureKind.emailTaken);
    }
    if (error is supabase.AuthWeakPasswordException ||
        code == 'weak_password') {
      return const AuthFailure(AuthFailureKind.weakPassword);
    }
    if (code == 'email_address_invalid' ||
        (code == 'validation_failed' && message.contains('email'))) {
      return const AuthFailure(AuthFailureKind.invalidEmail);
    }
    // Type and codes only: the message can contain the email address.
    debugPrint(
      'Timer: unmapped auth error ${error.runtimeType} code=$code status=$status',
    );
    return const AuthFailure(AuthFailureKind.unknown);
  }
  debugPrint('Timer: unmapped auth error ${error.runtimeType}');
  return const AuthFailure(AuthFailureKind.unknown);
}
