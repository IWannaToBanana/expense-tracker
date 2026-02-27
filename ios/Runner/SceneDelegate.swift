import Flutter
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = (scene as? UIWindowScene) else { return }

    // 使用已初始化的 Flutter 引擎
    let flutterViewController = FlutterViewController(engine: FlutterEngineProvider.shared.engine, nibName: nil, bundle: nil)
    window = UIWindow(windowScene: windowScene)
    window?.rootViewController = flutterViewController
    window?.makeKeyAndVisible()

    // 处理启动时的 URL
    if let url = connectionOptions.urlContexts.first?.url {
      handleURL(url)
    }
  }

  func sceneDidDisconnect(_ scene: UIScene) {
  }

  func sceneDidBecomeActive(_ scene: UIScene) {
  }

  func sceneWillResignActive(_ scene: UIScene) {
  }

  func sceneWillEnterForeground(_ scene: UIScene) {
  }

  func sceneDidEnterBackground(_ scene: UIScene) {
  }

  // 处理通过 URL 分享的内容
  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    if let url = URLContexts.first?.url {
      handleURL(url)
    }
  }

  private func handleURL(_ url: URL) {
    // receive_sharing_intent 插件会自动处理 URL
    // 这里只需要确保 Flutter 引擎能够接收 URL 事件
    let controller = window?.rootViewController as? FlutterViewController
    controller?.handleOpen(url)
  }
}
