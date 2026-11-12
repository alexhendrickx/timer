import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timer/core/services/database/app_database.dart';
import 'package:timer/feature/activities/data/activity_repository.dart';
import 'package:timer/feature/sync/service/auth_service.dart';
import 'package:timer/feature/sync/service/sync_engine.dart';
import 'package:timer/feature/sync/service/sync_models.dart';
import 'package:timer/feature/sync/service/supabase_sync_port.dart';

/// Fake auth backend — flips signed in/out without any live network.
class _FakeAuthBackend implements SyncAuthBackend {
  @override
  String? currentUserId;
  final _controller = StreamController<String?>.broadcast();

  @override
  Stream<String?> get userIdChanges => _controller.stream;

  @override
  Future<String> signInWithIdToken({
    required String idToken,
    String? nonce,
  }) async {
    currentUserId = 'user-1';
    _controller.add(currentUserId);
    return currentUserId!;
  }

  @override
  Future<void> signOut() async {
    currentUserId = null;
    _controller.add(null);
  }
}

/// Fake [SyncPort] — records upserts, and can be made to throw to
/// simulate being offline.
class _FakeSyncPort implements SyncPort {
  final List<SyncRow> upserts = [];
  List<SyncRow> remote = [];
  bool throwOnUpsert = false;

  @override
  Future<void> upsert(String table, List<SyncRow> rows) async {
    if (throwOnUpsert) throw Exception('offline');
    upserts.addAll(rows);
  }

  @override
  Future<List<SyncRow>> fetchSince(DateTime since, String table) async {
    return remote;
  }
}

void main() {
  late AppDatabase db;
  late ActivityRepository activities;
  late _FakeAuthBackend backend;
  late AuthService auth;
  late _FakeSyncPort port;
  late SyncEngine engine;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    activities = ActivityRepository(db);
    backend = _FakeAuthBackend();
    auth = AuthService(backend: backend);
    port = _FakeSyncPort();
    engine = SyncEngine(db: db, auth: auth, port: port);
  });

  tearDown(() => db.close());

  test('syncNow does nothing when signed out', () async {
    await activities.create(name: 'Client X');
    await engine.syncNow();
    expect(port.upserts, isEmpty);
  });

  test('dirty local rows are pushed then marked clean', () async {
    await backend.signInWithIdToken(idToken: 'tok');
    final id = await activities.create(name: 'Client X');

    await engine.syncNow();

    expect(port.upserts, hasLength(1));
    final row = await (db.select(db.activities)..where((a) => a.id.equals(id)))
        .getSingle();
    expect(row.dirty, false);
  });

  test('remote-only uid is inserted once (idempotent on uid)', () async {
    await backend.signInWithIdToken(idToken: 'tok');
    port.remote = [
      SyncRow(
        uid: 'r1',
        updatedAt: DateTime(2026, 1, 1),
        fields: const {'name': 'From Remote', 'archived': false},
      ),
    ];

    await engine.syncNow();
    await engine.syncNow();

    final matches =
        (await db.select(db.activities).get()).where((a) => a.uid == 'r1');
    expect(matches.length, 1);
  });

  test('offline writes queue and drain on reconnect', () async {
    await backend.signInWithIdToken(idToken: 'tok');
    await activities.create(name: 'A');
    await activities.create(name: 'B');
    port.throwOnUpsert = true;

    await engine.syncNow(); // offline: push fails, nothing recorded
    expect(port.upserts, isEmpty);

    port.throwOnUpsert = false;
    engine.onReconnect();
    await pumpEventQueue();

    expect(port.upserts.length, 2);
  });
}
