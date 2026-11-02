import UIKit

/// The application delegate. Window set-up lives in `SceneDelegate`.
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    /// Returns the window scene configuration declared in Info.plist.
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions,
    ) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}

/// Creates the window with the sample's one screen.
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    /// The scene's window.
    var window: UIWindow?

    /// Builds the window when the scene connects.
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions,
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UINavigationController(rootViewController: TransferViewController())
        window.makeKeyAndVisible()
        self.window = window
    }
}
