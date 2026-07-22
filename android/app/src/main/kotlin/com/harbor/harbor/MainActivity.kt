package com.harbor.harbor

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Android side of the Share Sheet bridge — mirrors
 * ios/Runner/ShareChannelHandler.swift so lib/core/services/share_intent_service.dart
 * talks to both platforms over the same "harbor/share" channel without
 * knowing which one it's on.
 *
 * Unlike iOS (which needs a separate Share Extension process + App Group),
 * Android lets MainActivity itself declare an ACTION_SEND intent-filter
 * (see AndroidManifest.xml) and receive the share directly.
 */
class MainActivity : FlutterActivity() {
  private val channelName = "harbor/share"
  private var methodChannel: MethodChannel? = null

  // Cold start: app wasn't running, share intent launched it. Dart isn't
  // listening yet, so we hold onto the value until it asks via
  // consumePendingShare().
  private var pendingSharedText: String? = null

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
    methodChannel?.setMethodCallHandler { call, result ->
      when (call.method) {
        "consumePendingShare" -> {
          result.success(pendingSharedText)
          pendingSharedText = null
        }
        else -> result.notImplemented()
      }
    }

    handleShareIntent(intent, isColdStart = true)
  }

  // Warm start: activity already running (launchMode="singleTop"), a new
  // share arrives as onNewIntent instead of a fresh onCreate.
  override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    setIntent(intent)
    handleShareIntent(intent, isColdStart = false)
  }

  private fun handleShareIntent(intent: Intent?, isColdStart: Boolean) {
    if (intent == null || intent.action != Intent.ACTION_SEND || intent.type != "text/plain") {
      return
    }
    val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT) ?: return

    if (isColdStart) {
      pendingSharedText = sharedText
    } else {
      methodChannel?.invokeMethod("onShareReceived", sharedText)
    }
  }
}
