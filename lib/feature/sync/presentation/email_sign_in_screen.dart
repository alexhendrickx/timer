import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../service/auth_failure.dart';
import '../service/auth_service.dart';
import '../service/mail_launcher.dart';
import 'widgets/email_sent_view.dart';

enum EmailAuthMode { signIn, createAccount }

enum _SentKind { confirmation, passwordReset }

/// Email + password: sign in, create an account, or ask for a reset link.
/// The password lives only in its text field and the one backend call.
class EmailSignInScreen extends StatefulWidget {
  const EmailSignInScreen({
    super.key,
    required this.auth,
    this.mail = const MailLauncher(),
  });

  final AuthService auth;
  final MailLauncher mail;

  /// Pushes the screen. Completes with true once the user is signed in.
  /// Mirrors `ActivityEditSheet.show`.
  static Future<bool?> show(
    BuildContext context, {
    required AuthService auth,
    MailLauncher mail = const MailLauncher(),
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EmailSignInScreen(auth: auth, mail: mail),
      ),
    );
  }

  @override
  State<EmailSignInScreen> createState() => _EmailSignInScreenState();
}

class _EmailSignInScreenState extends State<EmailSignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  EmailAuthMode _mode = EmailAuthMode.signIn;
  _SentKind? _sent; // non-null shows "Check your email"
  bool _busy = false;
  AuthFailure? _failure;
  String? _hint;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    widget.auth.removeListener(_onAuthChanged);
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  // Any route to a session closes the screen: a password sign-in, a sign-up
  // that needed no confirmation, or the confirmation link arriving.
  void _onAuthChanged() {
    if (!widget.auth.isSignedIn || _closed || !mounted) return;
    _closed = true;
    Navigator.of(context).pop(true);
  }

  String get _emailText => _email.text.trim();

  bool get _signingIn => _mode == EmailAuthMode.signIn;

  bool get _canSubmit =>
      !_busy &&
      _emailText.contains('@') &&
      (_signingIn
          ? _password.text.isNotEmpty
          : _password.text.length >= minPasswordLength);

  Future<void> _attempt(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _failure = null;
      _hint = null;
    });
    try {
      await action();
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _failure = failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() => _attempt(() async {
        if (_signingIn) {
          await widget.auth.signInWithEmail(
            email: _emailText,
            password: _password.text,
          );
          return;
        }
        final result = await widget.auth.signUpWithEmail(
          email: _emailText,
          password: _password.text,
        );
        if (result == EmailSignUpResult.confirmationSent && mounted) {
          setState(() => _sent = _SentKind.confirmation);
        }
      });

  Future<void> _forgotPassword() async {
    if (!_emailText.contains('@')) {
      setState(() => _hint = 'Enter your email first.');
      return;
    }
    await _attempt(() async {
      await widget.auth.sendPasswordReset(_emailText);
      if (mounted) setState(() => _sent = _SentKind.passwordReset);
    });
  }

  Future<void> _resendConfirmation() => _attempt(() async {
        await widget.auth.resendConfirmation(_emailText);
        if (mounted) setState(() => _sent = _SentKind.confirmation);
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: _sent != null ? _sentView() : _form(context),
          ),
        ),
      ),
    );
  }

  Widget _sentView() {
    return EmailSentView(
      email: _emailText,
      mail: widget.mail,
      onResend: () => _sent == _SentKind.confirmation
          ? widget.auth.resendConfirmation(_emailText)
          : widget.auth.sendPasswordReset(_emailText),
      onBack: () => setState(() {
        _sent = null;
        _mode = EmailAuthMode.signIn;
        _password.clear();
      }),
    );
  }

  Widget _form(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Scrolls, so the keyboard and the short Mac window never overflow.
          Expanded(
            child: ListView(
              children: [
                Text(
                  _signingIn ? 'Sign in with email' : 'Create your account',
                  style: textTheme.headlineSmall,
                ),
                const SizedBox(height: 20),
                _modeSwitch(),
                const SizedBox(height: 20),
                _fields(),
                if (_signingIn)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _busy ? null : _forgotPassword,
                      child: const Text('Forgot password?'),
                    ),
                  ),
                if (_hint != null || _failure != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _hint ?? _failure!.message,
                    style:
                        textTheme.bodyMedium?.copyWith(color: AppColors.danger),
                  ),
                ],
                if (_failure?.kind == AuthFailureKind.emailNotConfirmed)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      key: const Key('email-resend-confirmation'),
                      onPressed: _busy ? null : _resendConfirmation,
                      child: const Text('Resend confirmation email'),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('email-submit'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            onPressed: _canSubmit ? _submit : null,
            child: Text(_signingIn ? 'Sign in' : 'Create account'),
          ),
        ],
      ),
    );
  }

  Widget _modeSwitch() {
    return SegmentedButton<EmailAuthMode>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: EmailAuthMode.signIn, label: Text('Sign in')),
        ButtonSegment(
          value: EmailAuthMode.createAccount,
          label: Text('Create account'),
        ),
      ],
      selected: {_mode},
      onSelectionChanged: (selection) => setState(() {
        _mode = selection.first;
        _failure = null;
        _hint = null;
      }),
    );
  }

  // One AutofillGroup, so the OS Keychain can fill and offer to save the
  // pair. Its default dispose action (commit) is what triggers the save.
  Widget _fields() {
    return AutofillGroup(
      child: Column(
        children: [
          TextField(
            key: const Key('email-field'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Email'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('password-field'),
            controller: _password,
            obscureText: true,
            autofillHints: [
              _signingIn ? AutofillHints.password : AutofillHints.newPassword,
            ],
            decoration: InputDecoration(
              labelText: 'Password',
              helperText: _signingIn ? null : 'At least 8 characters.',
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (_canSubmit) _submit();
            },
          ),
        ],
      ),
    );
  }
}
