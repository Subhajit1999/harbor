import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/router/app_routes.dart';
import '../../core/services/settings_service.dart';
import '../../core/utils/app_logger.dart';
import '../../data/download/download_manager.dart';
import '../../data/api/harbor_api.dart';
import '../../domain/entities/download_entity.dart';
import '../../domain/entities/media_variant.dart';

const _tag = 'ImportController';

/// Drives the whole import flow: Import screen (paste/analyze) → Analysis
/// screen (variant selection) → Save Destination sheet → enqueue. Kept as
/// one controller across the flow (rather than one per screen) because the
/// state — the URL, the resolved metadata, the chosen variant — is
/// naturally sequential and shared, not screen-local.
class ImportController extends GetxController {
  final HarborApi _api = Get.find<HarborApi>();
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

  bool isSupported(String url) => _api.isSupported(url);

  Future<void> removeRecentLink(String url) async {
    await _settingsService.removeRecentLink(url);
    recentLinks.value = _settingsService.recentLinks;
  }

  Future<void> clearRecentLinks() async {
    await _settingsService.clearHistory();
    recentLinks.value = _settingsService.recentLinks;
  }

  Future<void> analyze([String? overrideUrl]) async {
    if (isAnalyzing.value) return;
    final url = (overrideUrl ?? linkController.text).trim();
    if (url.isEmpty) return;

    if (!_api.isSupported(url)) {
      AppLogger.w(_tag, 'API does not support "$url"');
      analysisError.value =
          'This link isn\'t from a supported source (YouTube, Instagram, or Facebook).';
      return;
    }

    AppLogger.i(_tag, 'analyze("$url") via HarborApi');
    isAnalyzing.value = true;
    analysisError.value = null;
    metadata.value = null;

    final stopwatch = Stopwatch()..start();
    try {
      final result = await _api.analyze(url);
      AppLogger.i(
        _tag,
        'analyze("$url") via HarborApi succeeded in ${stopwatch.elapsedMilliseconds}ms — '
        '${result.videoVariants.length} video + ${result.audioVariants.length} audio variant(s)',
      );
      metadata.value = result;
      await _settingsService.pushRecentLink(url);
      recentLinks.value = _settingsService.recentLinks;
      Get.toNamed(AppRoutes.analysis);
    } on ApiException catch (e, st) {
      AppLogger.e(
        _tag,
        'analyze("$url") via HarborApi failed after ${stopwatch.elapsedMilliseconds}ms: ${e.message}',
        e.cause,
        st,
      );
      analysisError.value = e.message;
    } on SocketException catch (e, st) {
      AppLogger.e(_tag, 'analyze("$url") via HarborApi: no internet', e, st);
      analysisError.value =
          'No internet connection. Check your network and try again.';
    } on TimeoutException catch (e, st) {
      AppLogger.e(_tag, 'analyze("$url") via HarborApi: timed out', e, st);
      analysisError.value =
          'This is taking too long — the source may be slow to respond. Try again.';
    } catch (e, st) {
      // Not an ApiException/network error — a bug or something
      // genuinely unexpected. Keep it visible (not swallowed) but framed as
      // unexpected rather than showing a raw exception string.
      AppLogger.e(
          _tag, 'analyze("$url") via HarborApi: unexpected error', e, st);
      analysisError.value =
          'Something unexpected went wrong analyzing this link. ($e)';
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
      AppLogger.i(_tag, 'Enqueued download ${download.id} (${meta.title})');
    } catch (e, st) {
      AppLogger.e(
          _tag, 'Failed to enqueue download for "${meta.title}"', e, st);
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

    // Reset flow state and drop back to Home; switch to Downloads tab (index 2)
    linkController.clear();
    metadata.value = null;
    selectedVariant.value = null;

    Get.offAllNamed(AppRoutes.home);
    // Note: The download queue is accessible from Home, so dropping them at Home is sufficient.

    Get.snackbar(
      'Added to Downloads',
      meta.title,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.accentDark,
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
      icon: const Icon(CupertinoIcons.cloud_download, color: Colors.white),
    );
  }
}
