import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  // Must match the entitlement in Runner.entitlements and the widget
  // extension's own entitlement (once that target exists — see
  // ios/TimerWidget/README.md).
  static let appGroupId = "group.com.alexhendrickx.timer"

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
      appGroupChannel.setMethodCallHandler { [weak self] call, result in
        guard call.method == "containerPath" else {
          result(FlutterMethodNotImplemented)
          return
        }
        let url = FileManager.default.containerURL(
          forSecurityApplicationGroupIdentifier: AppDelegate.appGroupId
        )
        result(url?.path)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
