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
  private var muxHandler: MuxHandler? = null

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

    muxHandler = MuxHandler(flutterEngine.dartExecutor.binaryMessenger)

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
    // Loosened from an exact "text/plain" match — some apps send a type
    // with parameters (e.g. "text/plain; charset=utf-8"), which failed
    // this check and made the share silently no-op (app opens to Home,
    // nothing imported — easy to mistake for "nothing happens" if it's
    // fast). startsWith covers that without widening scope to non-text
    // shares (images, etc.) we can't do anything with anyway.
    if (intent == null || intent.action != Intent.ACTION_SEND ||
      intent.type?.startsWith("text/") != true
    ) {
      return
    }
    val rawText = intent.getStringExtra(Intent.EXTRA_TEXT) ?: return
    // Some apps share a caption + link together rather than a clean URL
    // string — pull the first URL substring out instead of requiring the
    // whole extra to be exactly a URL.
    val sharedText = firstUrl(rawText) ?: rawText

    if (isColdStart) {
      pendingSharedText = sharedText
    } else {
      methodChannel?.invokeMethod("onShareReceived", sharedText)
    }
  }

  private fun firstUrl(text: String): String? {
    val matcher = android.util.Patterns.WEB_URL.matcher(text)
    return if (matcher.find()) matcher.group() else null
  }
}
