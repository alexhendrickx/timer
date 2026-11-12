import 'package:flutter_test/flutter_test.dart';
import 'package:timer/core/platform/ios/deep_link_listener.dart';
import 'package:timer/core/platform/ios/quick_start_intent_handler.dart';

void main() {
  test('bare quick-start link has no activityId', () {
    final intent = parseDeepLink('timer://quick-start');
    expect(intent.activityId, isNull);
  });

  test('link with activityId parses it', () {
    final intent = parseDeepLink('timer://quick-start?activityId=5');
    expect(intent.activityId, 5);
  });

  test('malformed activityId falls back to null, not a crash', () {
    final intent = parseDeepLink('timer://quick-start?activityId=banana');
    expect(intent.activityId, isNull);
  });

  test('type is QuickStartIntent', () {
    expect(parseDeepLink('timer://quick-start'), isA<QuickStartIntent>());
  });
}
