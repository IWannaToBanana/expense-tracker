import Flutter
import UIKit

@main
class AppDelegate: FlutterAppDelegate {
  private var methodChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    methodChannel = FlutterMethodChannel(name: "com.example.expenseTracker/deeplink",
                                         binaryMessenger: controller.binaryMessenger)
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // 重写该方法以手动接管自定义 URL scheme 的唤醒 (Deep Link) 
  // 放弃不稳定的 uni_links, 自己建桥直连 Flutter
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    methodChannel?.invokeMethod("onDeepLink", arguments: url.absoluteString)
    return super.application(app, open: url, options: options)
  }
}
