import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart'
    show SignInWithAppleButton, SignInWithAppleButtonStyle;

import '../../../../core/theme/app_colors.dart';
import '../../service/auth_failure.dart';
import '../../service/auth_service.dart';
import '../email_sign_in_screen.dart';

/// The three sign-in methods, shared by onboarding and Settings: Apple,
/// Google (only when its client ids were supplied) and email.
class SignInButtons extends StatefulWidget {
  const SignInButtons({super.key, required this.auth, this.onSignedIn});

  final AuthService auth;

  /// Called once after any of the three methods signs the user in.
  final VoidCallback? onSignedIn;

  @override
  State<SignInButtons> createState() => _SignInButtonsState();
}

class _SignInButtonsState extends State<SignInButtons> {
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() signIn) async {
    final onSignedIn = widget.onSignedIn;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await signIn();
      onSignedIn?.call();
    } on AuthFailure catch (failure) {
      if (mounted && failure.kind != AuthFailureKind.cancelled) {
        setState(() => _error = failure.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _email() async {
    final onSignedIn = widget.onSignedIn;
    final signedIn = await EmailSignInScreen.show(context, auth: widget.auth);
    if (signedIn == true) onSignedIn?.call();
  }

  @override
  Widget build(BuildContext context) {
    final outlined = OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(56),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SignInWithAppleButton(
          height: 56,
          style: SignInWithAppleButtonStyle.white,
          onPressed:
              _busy ? null : () => _run(widget.auth.signInWithApple),
        ),
        if (widget.auth.googleAvailable) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: outlined,
            icon: const Icon(Icons.g_mobiledata, size: 28),
            label: const Text('Sign in with Google'),
            onPressed:
                _busy ? null : () => _run(widget.auth.signInWithGoogle),
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: outlined,
          icon: const Icon(Icons.mail_outline),
          label: const Text('Continue with email'),
          onPressed: _busy ? null : _email,
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.danger),
          ),
        ],
      ],
    );
  }
}
