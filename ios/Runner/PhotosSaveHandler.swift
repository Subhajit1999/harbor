import Flutter
import Photos

/// Native counterpart to lib/core/services/media_save_service.dart. Saves a
/// downloaded file into the Photos library via `PHPhotoLibrary` directly —
/// used instead of a Flutter plugin (`photo_manager`) so permission
/// requests and save failures surface exact, debuggable errors back to
/// Dart instead of being swallowed inside a third-party wrapper.
class PhotosSaveHandler {
  private let channel: FlutterMethodChannel

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "harbor/photos", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "saveToPhotos":
        guard
          let args = call.arguments as? [String: Any],
          let path = args["path"] as? String,
          let isVideo = args["isVideo"] as? Bool
        else {
          result(FlutterError(code: "bad_args", message: "Missing path/isVideo", details: nil))
          return
        }
        PhotosSaveHandler.save(path: path, isVideo: isVideo, result: result)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func save(path: String, isVideo: Bool, result: @escaping FlutterResult) {
    PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
      switch status {
      case .authorized, .limited:
        performSave(path: path, isVideo: isVideo, result: result)
      case .denied, .restricted:
        DispatchQueue.main.async {
          result(FlutterError(
            code: "permission_denied",
            message: "Photos access was denied.",
            details: nil
          ))
        }
      case .notDetermined:
        // requestAuthorization only calls back with .notDetermined if the
        // system couldn't present the prompt (e.g. no active window) —
        // nothing more to try here.
        DispatchQueue.main.async {
          result(FlutterError(
            code: "permission_denied",
            message: "Photos permission could not be determined.",
            details: nil
          ))
        }
      @unknown default:
        DispatchQueue.main.async {
          result(FlutterError(code: "permission_denied", message: "Photos access unavailable.", details: nil))
        }
      }
    }
  }

  private static func performSave(path: String, isVideo: Bool, result: @escaping FlutterResult) {
    let url = URL(fileURLWithPath: path)
    PHPhotoLibrary.shared().performChanges({
      if isVideo {
        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
      } else {
        PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
      }
    }) { success, error in
      // `completionHandler` fires on a background queue — hop back to main
      // before calling into Flutter, matching Flutter's threading contract.
      DispatchQueue.main.async {
        if success {
          result(true)
        } else {
          result(FlutterError(
            code: "save_failed",
            message: error?.localizedDescription ?? "Unknown Photos save error.",
            details: nil
          ))
        }
      }
    }
  }
}
