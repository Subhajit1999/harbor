import UIKit
import UniformTypeIdentifiers
import Social

/// The UI that appears when the user taps "Harbor" in the iOS Share Sheet.
/// Deliberately minimal — extract the shared URL, hand it to the host app,
/// dismiss. All the actual link analysis happens in the Flutter app itself
/// (the Import screen), not here.
///
/// Handoff goes through UIPasteboard (a custom type, not the plain-text
/// slot) instead of an App Group container — App Groups needs a paid Apple
/// Developer Program membership, which this project doesn't assume.
/// `harborSharedURLPasteboardType` here MUST match
/// ios/Runner/ShareChannelHandler.swift exactly.
class ShareViewController: UIViewController {
  private let sharedURLPasteboardType = "com.harbor.harbor.sharedurl"

  override func viewDidLoad() {
    super.viewDidLoad()
    extractSharedURL { [weak self] sharedURL in
      guard let self else { return }
      guard let sharedURL else {
        self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        return
      }
      self.saveToPasteboard(sharedURL)
      self.openHostApp()
    }
  }

  private func extractSharedURL(completion: @escaping (String?) -> Void) {
    guard
      let item = extensionContext?.inputItems.first as? NSExtensionItem,
      let attachment = item.attachments?.first
    else {
      completion(nil)
      return
    }

    // Instagram/Facebook/YouTube share sheets typically hand off a URL
    // attachment directly; fall back to plain text in case the source app
    // shares the link as text instead.
    if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
      attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { data, _ in
        completion((data as? URL)?.absoluteString)
      }
    } else if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
      attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { data, _ in
        completion(data as? String)
      }
    } else {
      completion(nil)
    }
  }

  private func saveToPasteboard(_ url: String) {
    // Short expiration so a share that's never consumed (extension killed,
    // app never opened) doesn't leave stale data sitting on the clipboard.
    let options: [UIPasteboard.OptionsKey: Any] = [.expirationDate: Date().addingTimeInterval(300)]
    UIPasteboard.general.setItems([[sharedURLPasteboardType: url]], options: options)
  }

  /// Share Extensions run in a separate process from the host app — the
  /// old "walk the responder chain to find UIApplication.openURL:" trick
  /// only works for in-process extension types (e.g. Today widgets), not
  /// Share Extensions, so it silently no-ops here. `NSExtensionContext`
  /// has its own `open(_:completionHandler:)` built for exactly this case:
  /// it asks the host process to open the URL on the extension's behalf.
  private func openHostApp() {
    guard let url = URL(string: "harbor://import") else {
      extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
      return
    }
    extensionContext?.open(url) { [weak self] _ in
      self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
  }
}
