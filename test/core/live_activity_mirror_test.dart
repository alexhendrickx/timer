import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timer/core/platform/ios/live_activity_bridge.dart';
import 'package:timer/core/platform/ios/live_activity_mirror.dart';
import 'package:timer/core/services/database/app_database.dart';
import 'package:timer/feature/activities/data/activity_repository.dart';
import 'package:timer/feature/tracker/data/session_repository.dart';
import 'package:timer/feature/tracker/service/start_coordinator.dart';
import 'package:timer/feature/tracker/service/timer_engine.dart';

class _FakeBridge implements LiveActivityBridge {
  /// Every call in order: `show:<sessionId>` or `end`.
  final log = <String>[];
  final shown = <LiveActivityPayload>[];
  bool failNextShow = false;

  @override
  Future<void> show(LiveActivityPayload payload) async {
    if (failNextShow) {
      failNextShow = false;
      throw StateError('ActivityKit said no');
    }
    log.add('show:${payload.sessionId}');
    shown.add(payload);
  }

  @override
  Future<void> end() async => log.add('end');
}

/// Session storage whose open-session lookup fails.
class _BrokenSessions extends SessionRepository {
  _BrokenSessions(super.db);

  @override
  Future<Session?> openSession() async => throw StateError('two open rows');
}

void main() {
  late AppDatabase db;
  late ActivityRepository activities;
  late SessionRepository sessions;
  late TimerEngine engine;
  late _FakeBridge bridge;
  late LiveActivityMirror mirror;
  late int a;
  late int b;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    activities = ActivityRepository(db);
    sessions = SessionRepository(db);
    a = await activities.create(name: 'Client A', color: 0xFF2E7D32);
    b = await activities.create(name: 'Client B');
    engine = TimerEngine(sessions, now: () => DateTime(2026, 11, 23, 9, 0));
    bridge = _FakeBridge();
    mirror = LiveActivityMirror(
      engine: engine,
      activityRepository: activities,
      sessionRepository: sessions,
      bridge: bridge,
    )..start();
  });

  tearDown(() async {
    mirror.dispose();
    await mirror.settled;
    await engine.stop();
    engine.dispose();
    await db.close();
  });

  test('start shows the session with its name, color and start time',
      () async {
    await engine.start(a);
    await mirror.settled;

    expect(bridge.log, ['show:${engine.running!.id}']);
    expect(bridge.shown.single.toMap(), {
      'sessionId': engine.running!.id,
      'activityName': 'Client A',
      'color': 0xFF2E7D32,
      'startedAtMs': DateTime(2026, 11, 23, 9, 0).millisecondsSinceEpoch,
    });
  });

  test('a switch shows the new session in place, with no end', () async {
    final coordinator = StartCoordinator(engine);
    await coordinator.requestStart(a);
    final first = engine.running!.id;
    await coordinator.confirmSwitch(b);
    await mirror.settled;
    final second = engine.running!.id;

    expect(second, isNot(first));
    expect(bridge.log, ['show:$first', 'show:$second']);
    expect(bridge.shown.last.activityName, 'Client B');
    expect(bridge.shown.last.color, isNull);
    expect(bridge.shown.last.startedAt, engine.running!.startTime);
  });

  test('stop ends the Live Activity', () async {
    await engine.start(a);
    final id = engine.running!.id;
    await engine.stop();
    await mirror.settled;

    expect(bridge.log, ['show:$id', 'end']);
  });

  test('a stop at an explicit time ends it too', () async {
    await engine.start(a);
    final id = engine.running!.id;
    await engine.stopSessionAt(id, DateTime(2026, 11, 23, 9, 30));
    await mirror.settled;

    expect(bridge.log, ['show:$id', 'end']);
  });

  test('stop-at-last-seen ends the Live Activity that outlived the app',
      () async {
    await sessions.startSession(
        activityId: a, start: DateTime(2026, 11, 23, 8, 0));
    await engine.detectOrphan();
    await engine.resumeStopAtLastSeen();
    await mirror.settled;

    expect(bridge.log, ['end']);
  });

  test('keep-going shows the session again', () async {
    final id = await sessions.startSession(
        activityId: a, start: DateTime(2026, 11, 23, 8, 0));
    await engine.detectOrphan();
    await engine.resumeKeepRunning();
    await mirror.settled;

    expect(bridge.log, ['show:$id']);
  });

  test('endStale ends a Live Activity when no session is open', () async {
    await mirror.endStale();

    expect(bridge.log, ['end']);
  });

  test('endStale leaves an open session\'s Live Activity alone', () async {
    await sessions.startSession(
        activityId: a, start: DateTime(2026, 11, 23, 8, 0));
    await mirror.endStale();

    expect(bridge.log, isEmpty);
  });

  test('an archived activity shows as Timer', () async {
    final c = await activities.create(name: 'Old client');
    await activities.archive(c);
    await engine.start(c);
    await mirror.settled;

    expect(bridge.shown.single.activityName, 'Timer');
    expect(bridge.shown.single.color, isNull);
  });

  test('a failing bridge call neither throws into start nor blocks later calls',
      () async {
    bridge.failNextShow = true;
    await engine.start(a);
    await mirror.settled;
    await engine.stop();
    await mirror.settled;

    expect(bridge.log, ['end']);
    final s = (await db.select(db.sessions).get()).single;
    expect(s.endTime, isNotNull);
  });

  test('endStale never throws, even when the database read fails', () async {
    final broken = LiveActivityMirror(
      engine: engine,
      activityRepository: activities,
      sessionRepository: _BrokenSessions(db),
      bridge: bridge,
    );

    await broken.endStale();

    expect(bridge.log, isEmpty);
  });
}
