import 'package:go_router/go_router.dart';

import '../../../feature/activities/data/activity_repository.dart';
import '../../../feature/tracker/service/start_coordinator.dart';

/// Payload handed in from the native side (Action button Shortcut, Siri
/// Shortcut, or a widget tile's deep link): either "just open the picker"
/// (null) or "try to start this activity".
class QuickStartIntent {
  const QuickStartIntent({this.activityId});

  final int? activityId;
}

/// Resolves a [QuickStartIntent] into navigation + a start, always through
/// [StartCoordinator] so the D1 switch confirm is honored. An
/// unknown/archived activity, or one that would need that confirm, falls
/// back to the `/quick-start` chooser rather than guessing — the chooser is
/// the only place with UI to ask.
class QuickStartIntentHandler {
  QuickStartIntentHandler({
    required this.router,
    required this.coordinator,
    required this.activityRepository,
  });

  final GoRouter router;
  final StartCoordinator coordinator;
  final ActivityRepository activityRepository;

  Future<void> handle(QuickStartIntent intent) async {
    final activityId = intent.activityId;
    if (activityId == null) {
      router.go('/quick-start');
      return;
    }

    final active = await activityRepository.activeActivities();
    if (!active.any((a) => a.id == activityId)) {
      router.go('/quick-start');
      return;
    }

    final outcome = await coordinator.requestStart(activityId);
    if (outcome.kind == StartKind.needsSwitchConfirm) {
      // Never silently switch — land on the chooser, which has the D1
      // confirm dialog wired to a tap.
      router.go('/quick-start');
      return;
    }

    router.go('/running');
  }
}
