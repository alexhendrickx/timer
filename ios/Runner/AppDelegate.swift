import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  // Must match the entitlement in Runner.entitlements and the widget
  // extension's own entitlement (once that target exists — see
  // ios/TimerWidget/README.md).
  static let appGroupId = "group.com.alexhendrickx.timer"

  /// A `timer://` link that arrived before Flutter's `timer/deep_link`
  /// channel was listening (cold launch) — Dart pulls this once via
  /// `getInitialLink` instead of racing the engine startup with a push.
  private static var pendingDeepLink: String?

  private var deepLinkChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let appGroupChannel = FlutterMethodChannel(
        name: "timer/app_group",
        binaryMessenger: controller.binaryMessenger
      )
      appGroupChannel.setMethodCallHandler { call, result in
        guard call.method == "containerPath" else {
          result(FlutterMethodNotImplemented)
          return
        }
        let url = FileManager.default.containerURL(
          forSecurityApplicationGroupIdentifier: AppDelegate.appGroupId
        )
        result(url?.path)
      }

      let deepLinkChannel = FlutterMethodChannel(
        name: "timer/deep_link",
        binaryMessenger: controller.binaryMessenger
      )
      deepLinkChannel.setMethodCallHandler { call, result in
        guard call.method == "getInitialLink" else {
          result(FlutterMethodNotImplemented)
          return
        }
        result(AppDelegate.pendingDeepLink)
        AppDelegate.pendingDeepLink = nil
      }
      self.deepLinkChannel = deepLinkChannel
    }

    if let url = launchOptions?[.url] as? URL {
      AppDelegate.pendingDeepLink = url.absoluteString
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // The Action button Shortcut, Siri Shortcut, and widget tiles all open
  // the app at a `timer://` URL (registered in Info.plist) — this is the
  // system calling that back once the app is already running or just
  // became foreground.
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if let deepLinkChannel {
      deepLinkChannel.invokeMethod("onDeepLink", arguments: url.absoluteString)
    } else {
      AppDelegate.pendingDeepLink = url.absoluteString
    }
    return true
  }
}
