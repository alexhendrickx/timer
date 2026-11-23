import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timer/core/platform/ios/deep_link_listener.dart';
import 'package:timer/core/platform/ios/quick_start_intent_handler.dart';
import 'package:timer/core/routing/app_router.dart';
import 'package:timer/core/routing/auth_callback.dart';
import 'package:timer/core/services/database/app_database.dart';
import 'package:timer/feature/activities/data/activity_repository.dart';
import 'package:timer/feature/tracker/data/session_repository.dart';
import 'package:timer/feature/tracker/service/start_coordinator.dart';
import 'package:timer/feature/tracker/service/timer_engine.dart';

const _channel = MethodChannel('timer/deep_link');
const _authCallback = 'timer://auth-callback?code=abc';

/// A link anyone can craft from a session of their own account.
const _tokenCallback = 'timer://auth-callback#access_token=A&refresh_token=R'
    '&expires_in=3600&token_type=bearer';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late AppDatabase db;
  late TimerEngine engine;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    engine = TimerEngine(SessionRepository(db));
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(_channel, null);
    _channel.setMethodCallHandler(null);
    engine.dispose();
    await db.close();
  });

  QuickStartIntentHandler buildHandler() {
    return QuickStartIntentHandler(
      router: buildAppRouter(),
      coordinator: StartCoordinator(engine),
      activityRepository: ActivityRepository(db),
    );
  }

  String location(QuickStartIntentHandler handler) =>
      handler.router.routeInformationProvider.value.uri.toString();

  /// Delivers [url] the way the running app gets it from AppDelegate.
  Future<void> sendWhileRunning(String url) async {
    final data = const StandardMethodCodec()
        .encodeMethodCall(MethodCall('onDeepLink', url));
    await messenger.handlePlatformMessage(_channel.name, data, (_) {});
  }

  test('isAuthCallbackUri is true only for timer://auth-callback', () {
    bool check(String url) => isAuthCallbackUri(Uri.parse(url));

    expect(check('timer://auth-callback'), true);
    expect(check('timer://auth-callback?code=abc'), true);
    expect(check('timer://quick-start'), false);
    expect(check('timer://quick-start?code=abc'), false);
    expect(check('https://example.com/auth-callback?code=abc'), false);
    expect(check('other://auth-callback'), false);
  });

  group('isAuthCodeCallbackUri', () {
    bool check(String url) => isAuthCodeCallbackUri(Uri.parse(url));

    test('accepts only an auth callback that carries a code', () {
      expect(check(_authCallback), true);
      expect(check('timer://auth-callback'), false);
      expect(check('timer://auth-callback#code=abc'), false);
      expect(check('timer://auth-callback?error=access_denied'), false);
      expect(check('timer://quick-start?code=abc'), false);
      expect(check('https://example.com/auth-callback?code=abc'), false);
      expect(check('other://auth-callback?code=abc'), false);
    });

    test('rejects a link that carries a ready-made session', () {
      expect(check(_tokenCallback), false);
      expect(check('$_tokenCallback&type=recovery'), false);
      expect(check('timer://auth-callback?access_token=A'), false);
      expect(check('timer://auth-callback?code=abc&access_token=A'), false);
      expect(check('timer://auth-callback?code=abc#access_token=A'), false);
    });

    test('rejects a malformed escape without throwing', () {
      expect(check('timer://auth-callback?code=%FF'), false);
      expect(check('timer://auth-callback?code=abc#x=%FF'), false);
    });
  });

  test('the quick-start handler still ignores a token-bearing auth callback',
      () {
    expect(isAuthCallbackUri(Uri.parse(_tokenCallback)), true);
    expect(quickStartIntentFor(_tokenCallback), isNull);
  });

  test('quickStartIntentFor ignores the auth callback and foreign schemes',
      () {
    expect(quickStartIntentFor(_authCallback), isNull);
    expect(
      quickStartIntentFor('com.googleusercontent.apps.123:/oauth2redirect'),
      isNull,
    );
    expect(quickStartIntentFor('::not a url::'), isNull);

    expect(quickStartIntentFor('timer://quick-start?activityId=5')!.activityId,
        5);
    final plain = quickStartIntentFor('timer://quick-start');
    expect(plain, isNotNull);
    expect(plain!.activityId, isNull);
  });

  test('a cold-start auth callback does not open the picker', () async {
    messenger.setMockMethodCallHandler(_channel, (call) async => _authCallback);
    final handler = buildHandler();
    final listener = DeepLinkListener(handler);

    await listener.processInitialLink();

    expect(location(handler), '/');
    expect(engine.running, isNull);
  });

  test('an auth callback arriving while running does not open the picker',
      () async {
    final handler = buildHandler();
    DeepLinkListener(handler);

    await sendWhileRunning(_authCallback);
    await pumpEventQueue();

    expect(location(handler), '/');
    expect(engine.running, isNull);
  });

  test('a quick-start link still opens the picker', () async {
    final handler = buildHandler();
    DeepLinkListener(handler);

    await sendWhileRunning('timer://quick-start');
    await pumpEventQueue();

    expect(location(handler), '/quick-start');
  });

  test('a cold-start quick-start link still opens the picker', () async {
    messenger.setMockMethodCallHandler(
      _channel,
      (call) async => 'timer://quick-start',
    );
    final handler = buildHandler();
    final listener = DeepLinkListener(handler);

    await listener.processInitialLink();

    expect(location(handler), '/quick-start');
  });
}
