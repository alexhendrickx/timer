import Flutter
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  // Must match the entitlement in Runner.entitlements and the widget
  // extension's own entitlement (once that target exists — see
  // ios/TimerWidget/README.md).
  static let appGroupId = "group.be.alexhendrickx.timer"

  /// A `timer://` link that arrived before Flutter's `timer/deep_link`
  /// channel was listening (cold launch) — Dart pulls this once via
  /// `getInitialLink` instead of racing the engine startup with a push.
  private static var pendingDeepLink: String?

  private var deepLinkChannel: FlutterMethodChannel?

  /// `timer://` links other than the auth callback are quick-start links.
  /// `timer://auth-callback` belongs to Supabase (through app_links) and any
  /// other scheme (Google's redirect) to its own plugin.
  private static func isQuickStartLink(_ url: URL) -> Bool {
    return url.scheme?.lowercased() == "timer"
      && url.host?.lowercased() != "auth-callback"
  }

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
        switch call.method {
        case "containerPath":
          let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppDelegate.appGroupId
          )
          result(url?.path)
        case "reloadWidgets":
          if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
          }
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
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

    if let url = launchOptions?[.url] as? URL, AppDelegate.isQuickStartLink(url) {
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
    guard AppDelegate.isQuickStartLink(url) else {
      // Let the plugins see it. Without this call they never get a URL.
      _ = super.application(app, open: url, options: options)
      return true
    }
    if let deepLinkChannel {
      deepLinkChannel.invokeMethod("onDeepLink", arguments: url.absoluteString)
    } else {
      AppDelegate.pendingDeepLink = url.absoluteString
    }
    return true
  }
}
