# iOS Setup — Share Extension, App Groups, Photos/Files, Codegen

This project was written on a machine without Xcode or the Flutter SDK
available, so none of this has been built or run yet. Everything below is
what's needed on your Mac before Harbor is fully functional. Do these in
order — each step depends on the previous one existing.

## 0. Prerequisites

- Xcode (latest stable) and a paid or free Apple Developer account (needed
  for App Groups, which require a signed build — this won't work in the iOS
  Simulator's default signing).
- Flutter SDK (stable channel) on your Mac, matching or newer than the SDK
  constraint in `pubspec.yaml`.

## 1. Generate the standard Flutter iOS project

This repo has `lib/`, `pubspec.yaml`, and hand-written files under `ios/`,
but not the full Xcode project scaffold (`ios/Runner.xcodeproj`,
`ios/Podfile`, etc.) — that's machine-generated and shouldn't be
hand-written. From the project root:

```bash
flutter create . --org com.yourcompany --project-name harbor
```

This will *not* overwrite the `lib/` or `ios/Runner/AppDelegate.swift` /
`ios/ShareExtension/` files already here (Flutter only fills in what's
missing), but do a `git status` / diff afterward to confirm nothing you
care about got clobbered.

## 2. Install dependencies and generate Isar code

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

The second command generates `*.g.dart` files for the three Isar
collections (`media_model.g.dart`, `download_model.g.dart`,
`folder_model.g.dart`) — the app will not compile without this step.

## 3. Share Extension target — already wired up

The `ShareExtension` target is already in `Runner.xcodeproj` (added
programmatically, not via Xcode's New Target wizard — same end result).
`flutter create .` in step 1 won't touch it. Nothing to do here.

## 4. Extension ↔ app handoff — UIPasteboard, not App Groups

The normal way to pass data from a Share Extension to its host app is an
App Group container (`UserDefaults(suiteName:)`), but App Groups requires
a **paid** Apple Developer Program membership — a free/personal signing
team can't register that entitlement (you'll see errors like "Provisioning
profile doesn't include the App Groups capability" if you try).

So instead, `ShareViewController.swift` writes the shared URL to
`UIPasteboard.general` under a custom type identifier
(`com.harbor.harbor.sharedurl`, with a 5-minute expiration), and
`ShareChannelHandler.swift` reads + clears it. No entitlement, no App
Group ID to configure — works out of the box on any signing team.

If you later enroll in the paid program and want the more robust App Group
approach (survives longer, doesn't touch the system clipboard), swap both
files back to `UserDefaults(suiteName:)` and add the App Groups capability
in Signing & Capabilities on both targets.

## 5. Register the `harbor://` URL scheme

Already done — `CFBundleURLTypes` in `ios/Runner/Info.plist` registers the
`harbor` scheme directly. Nothing to do here.

## 6. Info.plist entries for Photos, Files, and background downloads

Already done — see `NSPhotoLibraryAddUsageDescription`,
`UIFileSharingEnabled`, and `LSSupportsOpeningDocumentsInPlace` in
`ios/Runner/Info.plist`.

The last two make Harbor's own Documents/Harbor folder (see
`MediaSaveService.saveToFiles`) show up as a location inside the iOS Files
app when "Files" is chosen as the save destination.

## 7. Background downloads (follow-up, not yet wired)

The current `DownloadManager` uses Dio directly, which does **not**
survive the app being fully terminated by iOS mid-download — only
backgrounded. To get true background-URLSession-backed downloads (survives
termination), the next step is a native `URLSession(configuration:
.background(withIdentifier:))` bridge, similar in shape to
`MuxHandler.swift`. This is a real gap worth closing before relying on
Harbor for large files, but didn't block getting the rest of the app
working end-to-end, so it's flagged here rather than silently glossed
over.

## 8. Build and run

```bash
flutter run
```

Test the Share Extension by opening Safari (or the YouTube/Instagram/
Facebook app) on your device, sharing a link, and confirming "Harbor"
appears in the share sheet and routes you into the Import screen with the
link pre-filled.

## Known rough edges to expect on first run

- `youtube_explode_dart`, `dio`, and the Instagram/Facebook resolvers were
  written without the ability to run them against live network access in
  this environment — expect to debug real HTTP responses/edge cases on
  your first live test, particularly the Instagram/Facebook HTML-scraping
  regexes, which are the most likely to need adjustment.
- No automated tests exist yet (see the main README's "Verification"
  section) — this is the top follow-up item.
