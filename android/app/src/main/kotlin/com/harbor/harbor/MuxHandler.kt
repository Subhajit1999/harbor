package com.harbor.harbor

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteBuffer
import java.util.concurrent.Executors

/**
 * Android counterpart to lib/data/download/mux_service.dart and
 * ios/Runner/MuxHandler.swift — same channel name ("harbor/mux") so
 * MuxService doesn't need to know which platform it's on.
 *
 * Currently only implements "extractAudio" (strip the audio track out of a
 * downloaded video into a standalone .m4a — needed because Instagram/
 * Facebook don't expose a separate audio-only CDN URL the way YouTube
 * does). Uses MediaExtractor/MediaMuxer, Android's built-in equivalent to
 * AVFoundation for this — no ffmpeg needed. YouTube's video+audio muxing
 * ("muxVideoAudio") isn't implemented here yet — that's iOS-only today,
 * a pre-existing gap this change doesn't address.
 */
class MuxHandler(messenger: BinaryMessenger) {
  private val channel = MethodChannel(messenger, "harbor/mux")
  private val mainHandler = Handler(Looper.getMainLooper())

  // MediaExtractor/MediaMuxer do blocking file I/O — must not run on the
  // platform thread the MethodChannel callback arrives on.
  private val executor = Executors.newSingleThreadExecutor()

  init {
    channel.setMethodCallHandler { call, result ->
      when (call.method) {
        "extractAudio" -> {
          val sourcePath = call.argument<String>("sourcePath")
          val outputPath = call.argument<String>("outputPath")
          if (sourcePath == null || outputPath == null) {
            result.error("bad_args", "Missing sourcePath/outputPath", null)
            return@setMethodCallHandler
          }
          executor.execute {
            try {
              extractAudio(sourcePath, outputPath)
              mainHandler.post { result.success(outputPath) }
            } catch (e: Exception) {
              mainHandler.post { result.error("extract_failed", e.message, null) }
            }
          }
        }
        else -> result.notImplemented()
      }
    }
  }

  private fun extractAudio(sourcePath: String, outputPath: String) {
    File(outputPath).delete() // MediaMuxer won't cleanly overwrite an existing file

    val extractor = MediaExtractor()
    var muxer: MediaMuxer? = null
    var muxerStarted = false
    try {
      extractor.setDataSource(sourcePath)

      var audioTrackIndex = -1
      var audioFormat: MediaFormat? = null
      for (i in 0 until extractor.trackCount) {
        val format = extractor.getTrackFormat(i)
        val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
        if (mime.startsWith("audio/")) {
          audioTrackIndex = i
          audioFormat = format
          break
        }
      }
      if (audioTrackIndex == -1 || audioFormat == null) {
        throw IllegalStateException("Source has no audio track.")
      }

      extractor.selectTrack(audioTrackIndex)

      val activeMuxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
      muxer = activeMuxer
      val muxerTrackIndex = activeMuxer.addTrack(audioFormat)
      activeMuxer.start()
      muxerStarted = true

      val buffer = ByteBuffer.allocate(1 shl 20) // 1MB
      val bufferInfo = MediaCodec.BufferInfo()

      while (true) {
        val sampleSize = extractor.readSampleData(buffer, 0)
        if (sampleSize < 0) break
        bufferInfo.offset = 0
        bufferInfo.size = sampleSize
        bufferInfo.presentationTimeUs = extractor.sampleTime
        bufferInfo.flags = extractor.sampleFlags
        activeMuxer.writeSampleData(muxerTrackIndex, buffer, bufferInfo)
        extractor.advance()
      }
    } finally {
      extractor.release()
      // stop() throws if the muxer was never started (e.g. we threw before
      // reaching it, or mid-loop) — only call it on one that actually
      // started, but always release() to free the native encoder either way.
      muxer?.let {
        if (muxerStarted) it.stop()
        it.release()
      }
    }
  }
}
