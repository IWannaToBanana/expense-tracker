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

    let flutterViewController = FlutterViewController()
    window = UIWindow(windowScene: windowScene)
    window?.rootViewController = flutterViewController
    window?.makeKeyAndVisible()

    // 处理启动时的 URL
    if let url = connectionOptions.urlContexts.first?.url {
      _ = flutterViewController.handleOpen(url)
    }
  }

  func sceneDidDisconnect(_ scene: UIScene) {}
  func sceneDidBecomeActive(_ scene: UIScene) {}
  func sceneWillResignActive(_ scene: UIScene) {}
  func sceneWillEnterForeground(_ scene: UIScene) {}
  func sceneDidEnterBackground(_ scene: UIScene) {}

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    if let url = URLContexts.first?.url,
       let flutterViewController = window?.rootViewController as? FlutterViewController {
      _ = flutterViewController.handleOpen(url)
    }
  }
}
