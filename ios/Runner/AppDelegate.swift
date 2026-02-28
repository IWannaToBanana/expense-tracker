import Flutter
import UIKit

@main
class AppDelegate: FlutterAppDelegate {
  private var methodChannel: FlutterMethodChannel?

  private var initialDeepLink: String?
  private var setupRetryCount = 0
  private let maxRetryCount = 50  // 最多重试 50 次（5秒）

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    print("🟢 AppDelegate: didFinishLaunchingWithOptions START")

    // 必须先调用 super 初始化 Flutter 引擎
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    print("🟢 AppDelegate: super.application() completed")

    // 然后注册插件
    GeneratedPluginRegistrant.register(with: self)
    print("🟢 AppDelegate: GeneratedPluginRegistrant.register() completed")

    // 延迟初始化 MethodChannel，确保 Flutter 引擎完全就绪
    DispatchQueue.main.async { [weak self] in
      print("🟢 AppDelegate: Starting MethodChannel setup...")
      self?.setupMethodChannel()
    }

    return result
  }

  private func setupMethodChannel() {
    print("🔧 AppDelegate: setupMethodChannel called, retry count: \(setupRetryCount)")

    // 防止无限重试
    guard setupRetryCount < maxRetryCount else {
      print("❌ AppDelegate: Max retry count reached, giving up")
      return
    }

    setupRetryCount += 1

    guard let controller = window?.rootViewController as? FlutterViewController else {
      print("⚠️ AppDelegate: FlutterViewController not ready (window: \(String(describing: window)), rootViewController: \(String(describing: window?.rootViewController)))")

      // 如果 FlutterViewController 还没准备好，稍后重试
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
        self?.setupMethodChannel()
      }
      return
    }

    print("✅ AppDelegate: FlutterViewController found, creating MethodChannel...")

    methodChannel = FlutterMethodChannel(name: "com.example.expenseTracker/deeplink",
                                         binaryMessenger: controller.binaryMessenger)

    methodChannel?.setMethodCallHandler({ [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      print("📨 Native: Method call received: \(call.method)")
      if call.method == "getInitialUri" {
        print("✅ Native: getInitialUri called, returning: \(self?.initialDeepLink ?? "nil")")
        result(self?.initialDeepLink)
        self?.initialDeepLink = nil // 取出后清空
      } else {
        print("⚠️ Native: Unknown method: \(call.method)")
        result(FlutterMethodNotImplemented)
      }
    })

    print("✅ AppDelegate: MethodChannel initialized successfully")
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
