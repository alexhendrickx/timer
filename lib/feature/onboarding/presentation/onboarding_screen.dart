import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/platform/platform_shell.dart';
import '../../../core/theme/app_colors.dart';
import '../../sync/service/auth_service.dart';
import 'widgets/activities_step.dart';
import 'widgets/quick_start_step.dart';
import 'widgets/sync_step.dart';

enum _Step { activities, sync, quickStart }

/// First-run setup: pick activities, optionally sign in to sync, learn the
/// quick-start shortcut. Every step can be skipped.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onFinished});

  /// Runs once, on "Skip setup" or "Done". The `/onboarding` route marks
  /// onboarding done and goes Home; widget tests pass a recorder.
  final Future<void> Function() onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final List<_Step> _steps;
  AuthService? _auth;
  int _index = 0;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthService?>();
    _auth = auth;
    // Fixed for the whole flow, so signing in mid-step cannot remove the
    // step the user is on.
    _steps = [
      _Step.activities,
      if (auth != null && !auth.isSignedIn) _Step.sync,
      _Step.quickStart,
    ];
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    try {
      await widget.onFinished();
    } catch (_) {
      // Stays latched on success only, so Skip and Done work after a failure.
      _finishing = false;
      rethrow;
    }
  }

  void _next() {
    // A sign-in can complete after a reset link replaced this screen.
    if (!mounted) return;
    if (_index >= _steps.length - 1) {
      _finish();
    } else {
      setState(() => _index += 1);
    }
  }

  /// Leaves the sync step, on "Not now" or after a sign-in.
  void _leaveSync() {
    // A sign-in can complete after "Not now" already moved past this step.
    if (_steps[_index] != _Step.sync) return;
    _next();
  }

  @override
  Widget build(BuildContext context) {
    final hasMenuBar = context.read<PlatformShell>().hasMenuBar;
    return Scaffold(
      body: SafeArea(
        child: Center(
          // The 480 max width is the whole Mac/iPhone layout difference.
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StepProgress(current: _index, total: _steps.length),
                  const SizedBox(height: 24),
                  Expanded(
                    child: switch (_steps[_index]) {
                      _Step.activities =>
                        ActivitiesStep(onNext: _next, onSkip: _finish),
                      _Step.sync => SyncStep(auth: _auth!, onNext: _leaveSync),
                      _Step.quickStart => QuickStartStep(
                          hasMenuBar: hasMenuBar,
                          onDone: _finish,
                        ),
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One segment per step; segments up to and including [current] are filled.
class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step ${current + 1} of $total',
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: i <= current ? AppColors.accent : AppColors.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
