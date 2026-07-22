import AVFoundation
import Flutter

/// Native counterpart to lib/data/download/mux_service.dart. Combines a
/// video-only track and an audio-only track (YouTube's 1080p+ adaptive
/// streams are served this way) into one playable file using
/// AVFoundation — which ships with iOS, so this avoids bundling ffmpeg
/// just for this one operation.
class MuxHandler {
  private let channel: FlutterMethodChannel

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "harbor/mux", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "muxVideoAudio":
        guard
          let args = call.arguments as? [String: String],
          let videoPath = args["videoPath"],
          let audioPath = args["audioPath"],
          let outputPath = args["outputPath"]
        else {
          result(FlutterError(code: "bad_args", message: "Missing videoPath/audioPath/outputPath", details: nil))
          return
        }

        Task {
          do {
            try await MuxHandler.mux(videoPath: videoPath, audioPath: audioPath, outputPath: outputPath)
            result(outputPath)
          } catch {
            result(FlutterError(code: "mux_failed", message: error.localizedDescription, details: nil))
          }
        }

      case "extractAudio":
        guard
          let args = call.arguments as? [String: String],
          let sourcePath = args["sourcePath"],
          let outputPath = args["outputPath"]
        else {
          result(FlutterError(code: "bad_args", message: "Missing sourcePath/outputPath", details: nil))
          return
        }

        Task {
          do {
            try await MuxHandler.extractAudio(sourcePath: sourcePath, outputPath: outputPath)
            result(outputPath)
          } catch {
            result(FlutterError(code: "extract_failed", message: error.localizedDescription, details: nil))
          }
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func mux(videoPath: String, audioPath: String, outputPath: String) async throws {
    let outputURL = URL(fileURLWithPath: outputPath)
    try? FileManager.default.removeItem(at: outputURL) // AVAssetExportSession refuses to overwrite

    let videoAsset = AVURLAsset(url: URL(fileURLWithPath: videoPath))
    let audioAsset = AVURLAsset(url: URL(fileURLWithPath: audioPath))

    let composition = AVMutableComposition()

    guard
      let videoTrack = try await videoAsset.loadTracks(withMediaType: .video).first,
      let audioTrack = try await audioAsset.loadTracks(withMediaType: .audio).first,
      let compVideoTrack = composition.addMutableTrack(
        withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
      let compAudioTrack = composition.addMutableTrack(
        withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
    else {
      throw NSError(domain: "MuxHandler", code: 1, userInfo: [
        NSLocalizedDescriptionKey: "Could not read video/audio tracks from downloaded files."
      ])
    }

    let videoDuration = try await videoAsset.load(.duration)
    let range = CMTimeRange(start: .zero, duration: videoDuration)

    try compVideoTrack.insertTimeRange(range, of: videoTrack, at: .zero)
    try compAudioTrack.insertTimeRange(range, of: audioTrack, at: .zero)

    guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
      throw NSError(domain: "MuxHandler", code: 2, userInfo: [
        NSLocalizedDescriptionKey: "Could not create export session."
      ])
    }
    export.outputURL = outputURL
    export.outputFileType = .mp4

    await export.export()

    if export.status != .completed {
      throw export.error ?? NSError(domain: "MuxHandler", code: 3, userInfo: [
        NSLocalizedDescriptionKey: "Export finished with status \(export.status.rawValue)."
      ])
    }
  }

  /// Strips just the audio track out of `sourcePath` (a full audio+video
  /// file — Instagram/Facebook don't expose a separate audio-only URL) into
  /// a standalone .m4a at `outputPath`. Unlike `mux`, this doesn't need a
  /// composition — there's only one track to keep, so the export session
  /// can read directly off the source asset with the dedicated M4A preset.
  private static func extractAudio(sourcePath: String, outputPath: String) async throws {
    let outputURL = URL(fileURLWithPath: outputPath)
    try? FileManager.default.removeItem(at: outputURL) // AVAssetExportSession refuses to overwrite

    let asset = AVURLAsset(url: URL(fileURLWithPath: sourcePath))

    guard try await asset.loadTracks(withMediaType: .audio).first != nil else {
      throw NSError(domain: "MuxHandler", code: 4, userInfo: [
        NSLocalizedDescriptionKey: "Source has no audio track."
      ])
    }

    guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
      throw NSError(domain: "MuxHandler", code: 2, userInfo: [
        NSLocalizedDescriptionKey: "Could not create export session."
      ])
    }
    export.outputURL = outputURL
    export.outputFileType = .m4a

    await export.export()

    if export.status != .completed {
      throw export.error ?? NSError(domain: "MuxHandler", code: 3, userInfo: [
        NSLocalizedDescriptionKey: "Export finished with status \(export.status.rawValue)."
      ])
    }
  }
}
