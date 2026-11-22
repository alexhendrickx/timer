import 'package:flutter/services.dart';

import '../../routing/auth_callback.dart';
import 'quick_start_intent_handler.dart';

/// Parses a `timer://quick-start[?activityId=<id>]` deep link (from the
/// Action button Shortcut, Siri Shortcut, or a widget tile) into a
/// [QuickStartIntent]. A missing or non-numeric `activityId` is treated as
/// "no id" — [QuickStartIntentHandler] already falls back to the picker for
/// that, same as an unknown one.
QuickStartIntent parseDeepLink(String url) {
  final uri = Uri.parse(url);
  final raw = uri.queryParameters['activityId'];
  return QuickStartIntent(activityId: raw == null ? null : int.tryParse(raw));
}

/// The quick-start intent for [url], or null when the link is not ours:
/// `timer://auth-callback` belongs to Supabase, and any other scheme (the
/// Google redirect) to its own plugin.
QuickStartIntent? quickStartIntentFor(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'timer' || isAuthCallbackUri(uri)) {
    return null;
  }
  return parseDeepLink(url);
}

/// Listens on the `timer/deep_link` channel (set up in
/// `ios/Runner/AppDelegate.swift`) for links the native side hands off —
/// both the one that cold-launched the app (pulled once via
/// `processInitialLink`) and any later one while already running (pushed
/// via `onDeepLink`) — and resolves each through [QuickStartIntentHandler].
class DeepLinkListener {
  DeepLinkListener(this._handler) {
    _channel.setMethodCallHandler(_onMethodCall);
  }

  static const _channel = MethodChannel('timer/deep_link');

  final QuickStartIntentHandler _handler;

  /// Call once at startup, after DI + resume-detection, so a cold launch
  /// from the Action button/Siri/a widget lands on the picker/running
  /// screen rather than a blank first frame.
  Future<void> processInitialLink() async {
    final initial = await _channel.invokeMethod<String>('getInitialLink');
    if (initial != null) await _handle(initial);
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    if (call.method == 'onDeepLink') {
      await _handle(call.arguments as String);
    }
    return null;
  }

  Future<void> _handle(String url) async {
    final intent = quickStartIntentFor(url);
    if (intent != null) await _handler.handle(intent);
  }
}
