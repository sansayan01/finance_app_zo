import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as! FlutterViewController
    let iconChannel = FlutterMethodChannel(
      name: "com.microflow.app_icon",
      binaryMessenger: controller.binaryMessenger
    )

    iconChannel.setMethodCallHandler { [weak self] (call, result) in
      switch call.method {
      case "isSupported":
        result(UIApplication.shared.supportsAlternateIcons)
      case "getCurrentIcon":
        let currentIcon = UIApplication.shared.alternateIconName ?? "default"
        result(currentIcon)
      case "setIcon":
        guard let args = call.arguments as? [String: Any],
              let iconName = args["iconName"] as? String else {
          result(FlutterError(code: "INVALID_ARG", message: "iconName is required", details: nil))
          return
        }
        self?.setAppIcon(iconName: iconName, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func setAppIcon(iconName: String, result: @escaping FlutterResult) {
    // "default" means reset to primary icon (nil)
    let alternateIconName: String? = (iconName == "default") ? nil : iconName

    UIApplication.shared.setAlternateIconName(alternateIconName) { error in
      if let error = error {
        print("⚠️ Failed to set alternate icon: \(error.localizedDescription)")
        result(false)
      } else {
        result(true)
      }
    }
  }
}
