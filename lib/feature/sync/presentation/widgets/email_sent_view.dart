import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../service/auth_failure.dart';
import '../../service/mail_launcher.dart';

/// "Check your email": shown after a confirmation or password-reset mail was
/// sent. Resend unlocks after a 60 s cooldown.
class EmailSentView extends StatefulWidget {
  const EmailSentView({
    super.key,
    required this.email,
    required this.mail,
    required this.onResend,
    required this.onBack,
  });

  final String email;
  final MailLauncher mail;
  final Future<void> Function() onResend;
  final VoidCallback onBack;

  @override
  State<EmailSentView> createState() => _EmailSentViewState();
}

class _EmailSentViewState extends State<EmailSentView> {
  static const _cooldownSeconds = 60;
  int _secondsLeft = _cooldownSeconds;
  Timer? _timer;
  bool _canOpenMail = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startCooldown(); // an email was just sent
    widget.mail.canOpen().then((ok) {
      if (mounted) setState(() => _canOpenMail = ok);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    _secondsLeft = _cooldownSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) timer.cancel();
      setState(() => _secondsLeft -= 1);
    });
  }

  Future<void> _resend() async {
    setState(() {
      _error = null;
      _startCooldown();
    });
    try {
      await widget.onResend();
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final locked = _secondsLeft > 0;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(child: _message(textTheme)),
            ),
          ),
          if (_error != null) ...[
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: AppColors.danger),
            ),
            const SizedBox(height: 12),
          ],
          if (_canOpenMail) ...[
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              onPressed: widget.mail.open,
              child: const Text('Open Mail'),
            ),
            const SizedBox(height: 12),
          ],
          TextButton(
            key: const Key('email-resend'),
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            onPressed: locked ? null : _resend,
            child: Text(
              locked ? 'Resend (available in $_secondsLeft s)' : 'Resend email',
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            onPressed: widget.onBack,
            child: const Text('Back to sign in'),
          ),
        ],
      ),
    );
  }

  Widget _message(TextTheme textTheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mail_outline,
            size: 34,
            color: AppColors.accent,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Check your email',
          textAlign: TextAlign.center,
          style: textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'We sent a link to ${widget.email}. '
          'Open it on this device to finish.',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
