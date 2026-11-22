import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../service/auth_failure.dart';
import '../service/auth_service.dart';

/// Shown after a password-reset link signed the user in: sets the new
/// password for that recovery session.
class SetPasswordScreen extends StatefulWidget {
  const SetPasswordScreen({super.key, required this.onDone});

  /// Called after the password is saved, or on "Not now".
  final VoidCallback onDone;

  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final auth = context.read<AuthService?>()!;
    final onDone = widget.onDone;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await auth.updatePassword(_password.text);
      onDone();
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSave = !_busy && _password.text.length >= minPasswordLength;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Set new password'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                TextField(
                  key: const Key('new-password-field'),
                  controller: _password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: const InputDecoration(
                    labelText: 'New password',
                    helperText: 'At least 8 characters.',
                  ),
                  onChanged: (_) => setState(() {}),
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
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('new-password-save'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                  onPressed: canSave ? _save : null,
                  child: const Text('Save password'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                  onPressed: widget.onDone,
                  child: const Text('Not now'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
