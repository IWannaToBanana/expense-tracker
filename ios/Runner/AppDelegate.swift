import Flutter
import UIKit

class FlutterEngineProvider {
  static let shared = FlutterEngineProvider()
  lazy var engine: FlutterEngine = {
    let engine = FlutterEngine(name: "io.flutter", project: nil)
    engine.run()
    return engine
  }()
}

@main
class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 预创建 Flutter 引擎，供 Scene 使用
    let engine = FlutterEngineProvider.shared.engine
    GeneratedPluginRegistrant.register(with: engine)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
