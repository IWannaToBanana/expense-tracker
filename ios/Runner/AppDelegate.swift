import Flutter
import UIKit

@main
class AppDelegate: FlutterAppDelegate {
  private var methodChannel: FlutterMethodChannel?
  private var initialDeepLink: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    // 延迟初始化 MethodChannel，确保 Flutter 引擎完全就绪
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
      self?.setupMethodChannel()
    }

    return result
  }

  private func setupMethodChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }

    methodChannel = FlutterMethodChannel(name: "com.example.expenseTracker/deeplink",
                                         binaryMessenger: controller.binaryMessenger)

    methodChannel?.setMethodCallHandler({ [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "getInitialUri" {
        result(self?.initialDeepLink)
        self?.initialDeepLink = nil
      } else {
        result(FlutterMethodNotImplemented)
      }
    })
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    let urlString = url.absoluteString

    if methodChannel == nil {
      // Flutter引擎还未初始化完毕（冷启动期间），先存起来
      initialDeepLink = urlString
    } else {
      // 已经在后台运行了（热启动），直接发去 Flutter
      DispatchQueue.main.async { [weak self] in
        self?.methodChannel?.invokeMethod("onDeepLink", arguments: urlString)
      }
    }

    return true
  }
}
