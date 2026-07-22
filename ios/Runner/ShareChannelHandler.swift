import Flutter
import UIKit

/// Dart-facing side of the Share Extension bridge. Handoff uses
/// UIPasteboard (a custom type identifier, not the plain-text slot) rather
/// than an App Group container — App Groups requires a paid Apple Developer
/// Program membership, and this needs to work on a free/personal signing
/// team too. The extension writes here with a short expiration
/// (see ShareViewController.swift); this type identifier MUST match there.
let harborSharedURLPasteboardType = "com.harbor.harbor.sharedurl"

class ShareChannelHandler {
  private let channel: FlutterMethodChannel

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "harbor/share", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      switch call.method {
      case "consumePendingShare":
        result(self.consumeAndClear())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func consumeAndClear() -> String? {
    let pasteboard = UIPasteboard.general
    guard let url = pasteboard.value(forPasteboardType: harborSharedURLPasteboardType) as? String
    else { return nil }
    // Clears the whole pasteboard — acceptable since we're consuming this
    // within moments of the extension writing it (no room for the user to
    // copy something else in between in practice).
    pasteboard.setItems([], options: [:])
    return url
  }

  /// Called by AppDelegate when `harbor://import` is opened while the app
  /// is already running (warm start) — pushes the value straight to Dart
  /// instead of waiting for Dart to poll.
  func notifyPendingShareAvailable() {
    if let url = consumeAndClear() {
      channel.invokeMethod("onShareReceived", arguments: url)
    }
  }
}
