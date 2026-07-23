import UIKit
import UniformTypeIdentifiers
import Social

/// The UI that appears when the user taps "Harbor" in the iOS Share Sheet.
/// Deliberately minimal — extract the shared URL, hand it to the host app,
/// dismiss. All the actual link analysis happens in the Flutter app itself
/// (the Import screen), not here.
///
/// Handoff goes through a *named* UIPasteboard (not `.general`, and not an
/// App Group container — App Groups needs a paid Apple Developer Program
/// membership, which this project doesn't assume). `sharedURLPasteboardType`
/// and `harborSharedPasteboardName` here MUST match
/// ios/Runner/ShareChannelHandler.swift exactly.
class ShareViewController: UIViewController {
  private let sharedURLPasteboardType = "com.harbor.harbor.sharedurl"
  private let harborSharedPasteboardName = UIPasteboard.Name("com.harbor.harbor.shareboard")

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

  /// Collects every attachment across every input item — some apps put the
  /// URL/text first, others put a thumbnail image or other representation
  /// first and the actual link second. Only checking `.first` (as this used
  /// to) means the extension silently does nothing for those apps: no
  /// attachment matches, `completion(nil)` fires, the request completes,
  /// and from the user's perspective Harbor just... didn't do anything.
  private func extractSharedURL(completion: @escaping (String?) -> Void) {
    let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
    let attachments = items.flatMap { $0.attachments ?? [] }

    guard !attachments.isEmpty else {
      completion(nil)
      return
    }

    // URL-typed attachments first (more apps use this than you'd think —
    // not just Safari), then fall back to plain text across every
    // attachment, trying each in order until one actually resolves.
    let urlAttachments = attachments.filter {
      $0.hasItemConformingToTypeIdentifier(UTType.url.identifier)
    }
    let textAttachments = attachments.filter {
      $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
    }

    tryLoadURL(from: urlAttachments) { [weak self] urlString in
      guard let self else { return }
      if let urlString {
        completion(urlString)
        return
      }
      self.tryLoadText(from: textAttachments, completion: completion)
    }
  }

  private func tryLoadURL(
    from attachments: [NSItemProvider], index: Int = 0,
    completion: @escaping (String?) -> Void
  ) {
    guard index < attachments.count else {
      completion(nil)
      return
    }
    attachments[index].loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) {
      [weak self] data, _ in
      if let urlString = (data as? URL)?.absoluteString {
        completion(urlString)
      } else {
        self?.tryLoadURL(from: attachments, index: index + 1, completion: completion)
      }
    }
  }

  private func tryLoadText(
    from attachments: [NSItemProvider], index: Int = 0,
    completion: @escaping (String?) -> Void
  ) {
    guard index < attachments.count else {
      completion(nil)
      return
    }
    attachments[index].loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) {
      [weak self] data, _ in
      // Some apps share a caption + link together ("Check this out
      // https://instagram.com/reel/xyz") rather than a clean URL string —
      // pull the first URL substring out rather than requiring the whole
      // string to be exactly a URL.
      if let text = data as? String, let urlString = Self.firstURL(in: text) {
        completion(urlString)
      } else {
        self?.tryLoadText(from: attachments, index: index + 1, completion: completion)
      }
    }
  }

  private static func firstURL(in text: String) -> String? {
    guard
      let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    else { return nil }
    let range = NSRange(text.startIndex..., in: text)
    return detector.firstMatch(in: text, options: [], range: range)?.url?.absoluteString
  }

  private func saveToPasteboard(_ url: String) {
    // A *named* pasteboard, not `.general` — reading `.general` cross-process
    // (extension writes, host app reads) makes iOS show its "<App> would
    // like to paste from <Other App>" consent alert on every single read,
    // including every ordinary cold start where nothing was even shared.
    // A named pasteboard created via `UIPasteboard(name:create:)` is treated
    // as app-owned shared storage and isn't subject to that prompt.
    let pasteboard = UIPasteboard(name: harborSharedPasteboardName, create: true)
    // Short expiration so a share that's never consumed (extension killed,
    // app never opened) doesn't leave stale data sitting on the clipboard.
    let options: [UIPasteboard.OptionsKey: Any] = [.expirationDate: Date().addingTimeInterval(300)]
    pasteboard?.setItems([[sharedURLPasteboardType: url]], options: options)
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
