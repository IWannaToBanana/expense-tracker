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
    
    if let controller = window?.rootViewController as? FlutterViewController {
      methodChannel = FlutterMethodChannel(name: "com.example.expenseTracker/deeplink",
                                           binaryMessenger: controller.binaryMessenger)
      
      methodChannel?.setMethodCallHandler({ [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
        if call.method == "getInitialUri" {
          result(self?.initialDeepLink)
          self?.initialDeepLink = nil // 取出后清空
        } else {
          result(FlutterMethodNotImplemented)
        }
      })
    }
    
    return result
  }
  
  // 重写该方法以手动接管自定义 URL scheme 的唤醒 (Deep Link) 
  // 放弃不稳定的 uni_links, 自己建桥直连 Flutter
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
      methodChannel?.invokeMethod("onDeepLink", arguments: urlString)
    }
    
    return super.application(app, open: url, options: options)
  }
}
