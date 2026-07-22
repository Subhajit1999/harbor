import UIKit
import Flutter

/// This project uses Flutter's scene-based lifecycle (see SceneDelegate.swift
/// + Info.plist's UIApplicationSceneManifest), so `window`/`rootViewController`
/// are NOT ready yet inside `application(_:didFinishLaunchingWithOptions:)` —
/// they're created when the scene connects, in SceneDelegate. That's also
/// why URL-open handling (`harbor://import`) lives in SceneDelegate's
/// `scene(_:openURLContexts:)` / `willConnectTo:options:`, not here —
/// UIKit routes URL opens through the scene delegate for scene-based apps,
/// not `application(_:open:options:)` (that's the pre-iOS-13 entry point).
@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
