import 'dart:async';
import 'package:flutter/services.dart';

/// Talks to the native side (`ios/Runner/ShareChannelHandler.swift`) to
/// retrieve links handed to Harbor via the iOS Share Extension.
///
/// How it fits together: the Share Extension (a separate app target,
/// `ios/ShareExtension/ShareViewController.swift`) can't launch the host
/// app's Flutter engine directly — extensions are short-lived, restricted
/// processes. So it writes the shared URL into a shared App Group
/// `UserDefaults` container and then asks iOS to open the host app via a
/// custom URL scheme (`harbor://import`). `AppDelegate.swift` catches that
/// URL open, and this channel is how Dart asks "was there a pending share"
/// on both cold start and while already running.
class ShareIntentService {
  static const _channel = MethodChannel('harbor/share');
  final _controller = StreamController<String>.broadcast();

  ShareIntentService() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onShareReceived' && call.arguments is String) {
        _controller.add(call.arguments as String);
      }
    });
  }

  /// Call once at startup — covers the case where Harbor was launched
  /// *by* tapping "Harbor" in the Share Sheet (cold start).
  Future<String?> consumePendingShare() async {
    return _channel.invokeMethod<String>('consumePendingShare');
  }

  /// Fires while the app is already running and the user shares another
  /// link in without fully backgrounding Harbor first.
  Stream<String> get onShareReceived => _controller.stream;
}
