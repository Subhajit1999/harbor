import Flutter
import UIKit

/// `FlutterSceneDelegate` (the superclass) sets up `window` and the
/// `FlutterViewController` when the scene connects — that's the first point
/// at which `window?.rootViewController` is actually a `FlutterViewController`,
/// which is why the method-channel setup lives here rather than in
/// AppDelegate's `didFinishLaunchingWithOptions`.
class SceneDelegate: FlutterSceneDelegate {
  var shareChannelHandler: ShareChannelHandler?
  var muxHandler: MuxHandler?

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    guard let controller = window?.rootViewController as? FlutterViewController else {
      fatalError("rootViewController is not FlutterViewController")
    }

    shareChannelHandler = ShareChannelHandler(messenger: controller.binaryMessenger)
    muxHandler = MuxHandler(messenger: controller.binaryMessenger)

    // Cold start (app launched BY opening harbor://import) deliberately
    // does nothing here beyond bringing the app up — the shared value is
    // already sitting on the pasteboard (see ShareViewController.swift),
    // and ShareIntentService.consumePendingShare() picks it up once Dart's
    // main() runs and registers its handler. Pushing via invokeMethod this
    // early would race Dart's handler registration and lose the call.
  }

  // Warm start: app already running, scene already connected, Dart is
  // already listening — UIKit calls this directly instead of reconnecting
  // the scene, so it's safe to push straight through.
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let url = URLContexts.first?.url, url.scheme == "harbor", url.host == "import" else {
      return
    }
    shareChannelHandler?.notifyPendingShareAvailable()
  }
}
