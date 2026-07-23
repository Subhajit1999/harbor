import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../core/router/app_routes.dart';
import '../../core/services/settings_service.dart';
import '../../data/download/download_manager.dart';
import '../../data/resolvers/resolver_registry.dart';
import '../../domain/entities/download_entity.dart';
import '../../domain/entities/media_variant.dart';
import '../../domain/repositories/link_resolver.dart';

/// Drives the whole import flow: Import screen (paste/analyze) → Analysis
/// screen (variant selection) → Save Destination sheet → enqueue. Kept as
/// one controller across the flow (rather than one per screen) because the
/// state — the URL, the resolved metadata, the chosen variant — is
/// naturally sequential and shared, not screen-local.
class ImportController extends GetxController {
  final ResolverRegistry _resolverRegistry = Get.find<ResolverRegistry>();
  final DownloadManager _downloadManager = Get.find<DownloadManager>();
  final SettingsService _settingsService = Get.find<SettingsService>();
  final _uuid = const Uuid();

  final linkController = TextEditingController();
  final recentLinks = <String>[].obs;

  final isAnalyzing = false.obs;
  final analysisError = RxnString();
  final metadata = Rxn<MediaMetadata>();
  final selectedVariant = Rxn<MediaVariant>();

  @override
  void onInit() {
    super.onInit();
    recentLinks.value = _settingsService.recentLinks;
    final arg = Get.arguments;
    if (arg is String && arg.isNotEmpty) {
      linkController.text = arg;
      analyze(arg);
    }
  }

  @override
  void onClose() {
    linkController.dispose();
    super.onClose();
  }

  Future<void> pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) linkController.text = data!.text!;
  }

  bool isSupported(String url) => _resolverRegistry.isSupported(url);

  Future<void> analyze([String? overrideUrl]) async {
    if (isAnalyzing.value) return;
    final url = (overrideUrl ?? linkController.text).trim();
    if (url.isEmpty) return;

    final resolver = _resolverRegistry.resolverFor(url);
    if (resolver == null) {
      analysisError.value =
          'This link isn\'t from a supported source (YouTube, Instagram, or Facebook).';
      return;
    }

    isAnalyzing.value = true;
    analysisError.value = null;
    metadata.value = null;

    try {
      final result = await resolver.analyze(url);
      metadata.value = result;
      await _settingsService.pushRecentLink(url);
      recentLinks.value = _settingsService.recentLinks;
      Get.toNamed(AppRoutes.analysis);
    } on ResolverException catch (e) {
      analysisError.value = e.message;
    } on SocketException {
      analysisError.value = 'No internet connection. Check your network and try again.';
    } on TimeoutException {
      analysisError.value = 'This is taking too long — the source may be slow to respond. Try again.';
    } catch (e) {
      // Not a ResolverException/network error — a resolver bug or something
      // genuinely unexpected. Keep it visible (not swallowed) but framed as
      // unexpected rather than showing a raw exception string.
      analysisError.value = 'Something unexpected went wrong analyzing this link. ($e)';
    } finally {
      isAnalyzing.value = false;
    }
  }

  void selectVariant(MediaVariant variant) {
    selectedVariant.value = variant;
  }

  /// Called once the user confirms a save destination in the bottom sheet.
  /// Builds the [DownloadEntity] and hands it to the download manager —
  /// from here the Download Queue screen owns the rest of the lifecycle.
  Future<void> confirmAndEnqueue(SaveDestination destination) async {
    final variant = selectedVariant.value;
    final meta = metadata.value;
    if (variant == null || meta == null) return;

    final download = DownloadEntity(
      id: _uuid.v4(),
      mediaTitle: meta.title,
      thumbnailUrl: meta.thumbnailUrl,
      sourceUrl: meta.sourceUrl,
      streamUrl: variant.streamUrl,
      audioStreamUrl: variant.audioStreamUrl,
      needsAudioExtraction: variant.needsAudioExtraction,
      type: variant.type,
      format: variant.container,
      resolution: variant.type == MediaType.video ? variant.label : null,
      duration: meta.duration,
      totalBytes: variant.estimatedSizeBytes ?? 0,
      startedAt: DateTime.now(),
      saveDestination: destination,
    );

    try {
      await _downloadManager.enqueue(download);
    } catch (e) {
      // Deliberately don't reset flow state or navigate away here — the
      // user is still on Analysis with the same variant selected, so they
      // can just try again instead of having to re-paste/re-analyze the
      // link from scratch.
      Get.snackbar(
        'Couldn\'t start download',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.black87,
        colorText: Colors.white,
      );
      return;
    }

    // Reset flow state and drop back to Home; the Download Queue (reachable
    // from Home's "Continue Download" section) shows live progress.
    linkController.clear();
    metadata.value = null;
    selectedVariant.value = null;
    Get.offAllNamed(AppRoutes.home);
    Get.snackbar('Download started', meta.title, snackPosition: SnackPosition.BOTTOM);
  }
}
