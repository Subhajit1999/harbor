import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:harbor/core/constants/app_constants.dart';
import 'package:harbor/data/resolvers/resolver_registry.dart';
import 'package:harbor/domain/entities/media_variant.dart';
import 'package:harbor/domain/repositories/link_resolver.dart';
import 'package:harbor/features/import/import_controller.dart';
import 'package:harbor/main.dart' as app;

/// Drives the real app end-to-end (Home -> Import -> Analysis -> Save
/// destination -> Download Queue) using Flutter's own gesture layer, not OS
/// accessibility/UI automation. A [_FakeResolver] stands in for the network
/// resolvers so the flow is deterministic and doesn't depend on YouTube
/// actually being reachable from the CI/simulator environment; it points at
/// a local HTTP server started by the test runner.
class _FakeResolver implements LinkResolver {
  final String streamUrl;
  _FakeResolver(this.streamUrl);

  @override
  String get name => 'FakeTest';

  @override
  bool canHandle(String url) => url.contains('faketest.local');

  @override
  Future<MediaMetadata> analyze(String url) async {
    return MediaMetadata(
      title: 'Integration Test Clip',
      thumbnailUrl: null,
      duration: const Duration(seconds: 5),
      source: MediaSource.unknown,
      sourceUrl: url,
      variants: [
        MediaVariant(
          id: 'fake_audio_1',
          type: MediaType.audio,
          label: '128 kbps',
          container: 'm4a',
          bitrateKbps: 128,
          estimatedSizeBytes: 200000,
          streamUrl: streamUrl,
        ),
      ],
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Import -> Analysis -> Save destination -> Download Queue', (tester) async {
    // The test runner started a local HTTP server serving this file
    // (see the accompanying shell driver) — passed in via --dart-define
    // so the test doesn't hardcode a port.
    const streamUrl = String.fromEnvironment(
      'TEST_STREAM_URL',
      defaultValue: 'http://127.0.0.1:8765/test_audio.m4a',
    );

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Splash -> Home should have happened by now.
    expect(find.text('Harbor'), findsWidgets);

    // Swap in the fake resolver now that InitialBindings has already run,
    // before navigating to Import (ImportController looks it up lazily).
    Get.put<ResolverRegistry>(
      ResolverRegistry(resolvers: [_FakeResolver(streamUrl)]),
      permanent: true,
    );

    // Home -> Import via the "Import" quick action.
    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();
    expect(find.text('Analyze'), findsOneWidget);

    // Paste the fake URL and analyze.
    await tester.enterText(find.byType(TextField), 'https://faketest.local/clip');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Analyze'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Debug: if the fake resolver didn't fire / navigation didn't happen,
    // print controller state so the log explains why instead of just
    // failing the text-not-found assertion below.
    final importController = Get.find<ImportController>();
    print('DEBUG isAnalyzing=${importController.isAnalyzing.value} '
        'analysisError=${importController.analysisError.value} '
        'metadata=${importController.metadata.value?.title} '
        'linkText=${importController.linkController.text}');
    print('DEBUG currentRoute=${Get.currentRoute}');

    // Import -> Analysis: the fake variant should be visible.
    expect(find.text('Integration Test Clip'), findsOneWidget);
    expect(find.text('128 kbps'), findsOneWidget);

    // Tap the variant tile -> Save Destination sheet.
    await tester.tap(find.text('128 kbps'));
    await tester.pumpAndSettle();
    expect(find.text('Save to'), findsOneWidget);

    await tester.tap(find.text('Files'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Download'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Enqueuing drops back to Home with a confirmation snackbar.
    expect(find.text('Download started'), findsOneWidget);

    // Home -> Download Queue via the "Downloads" quick action.
    await tester.tap(find.text('Downloads'));
    await tester.pumpAndSettle();
    expect(find.text('Integration Test Clip'), findsOneWidget);

    // Give the real download (against the local HTTP server) time to
    // finish, then confirm it reaches `completed` and gets indexed.
    var completed = false;
    for (var i = 0; i < 20; i++) {
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      if (find.text('Completed').evaluate().isNotEmpty) {
        completed = true;
        break;
      }
    }
    expect(completed, isTrue, reason: 'Download did not reach Completed within timeout');
  });
}
