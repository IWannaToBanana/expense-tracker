import Flutter
import UIKit

@main
class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // 保留最基本的 URL 处理，但只做日志，不做任何其他操作
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    print("📱 URL received: \(url.absoluteString)")
    // 不做任何处理，直接返回
    return true
  }
}
  
  // 重写该方法以手动接管自定义 URL scheme 的唤醒 (Deep Link)
  // 放弃不稳定的 uni_links, 自己建桥直连 Flutter
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    let urlString = url.absoluteString
    print("📱 Deep Link received: \(urlString)")

    // 确保在主线程执行 MethodChannel 相关操作
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }

      if self.methodChannel == nil {
        // Flutter引擎还未初始化完毕（冷启动期间），先存起来
        print("📦 Storing deep link for later (engine not ready)")
        self.initialDeepLink = urlString
      } else {
        // 已经在后台运行了（热启动），直接发去 Flutter
        print("🚀 Sending deep link to Flutter immediately")
        self.methodChannel?.invokeMethod("onDeepLink", arguments: urlString)
      }
    }

    return super.application(app, open: url, options: options)
  }
}
