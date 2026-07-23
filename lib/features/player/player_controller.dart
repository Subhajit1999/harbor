import 'dart:async';
import 'dart:io';
import 'package:chewie/chewie.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/settings_service.dart';
import '../../domain/entities/media_entity.dart';

/// Backs the single Player screen, which branches its UI on
/// `media.type` but shares one controller so speed/position/sleep-timer
/// logic isn't duplicated between a "video controller" and "audio
/// controller".
class PlayerController extends GetxController {
  final SettingsService _settingsService = Get.find<SettingsService>();

  late final MediaEntity media;
  VideoPlayerController? videoController;
  ChewieController? chewieController;
  final AudioPlayer audioPlayer = AudioPlayer();

  final isReady = false.obs;
  final isPlaying = false.obs;
  final position = Duration.zero.obs;
  final duration = Duration.zero.obs;
  final playbackSpeed = 1.0.obs;
  final sleepTimerRemaining = Rxn<Duration>();

  Timer? _sleepTimer;
  Timer? _positionTicker;

  @override
  void onInit() {
    super.onInit();
    media = Get.arguments as MediaEntity;
    playbackSpeed.value = _settingsService.defaultPlaybackSpeed;
    if (media.type == MediaType.video) {
      _initVideo();
    } else {
      _initAudio();
    }
  }

  Future<void> _initVideo() async {
    videoController = VideoPlayerController.file(File(media.path));
    await videoController!.initialize();
    videoController!.setPlaybackSpeed(playbackSpeed.value);
    final resumeAt = _settingsService.rememberPosition ? _settingsService.getPlaybackPosition(media.id) : null;
    if (resumeAt != null && resumeAt < videoController!.value.duration) {
      await videoController!.seekTo(resumeAt);
    }
    chewieController = ChewieController(
      videoPlayerController: videoController!,
      autoPlay: true,
      looping: false,
      allowPlaybackSpeedChanging: true,
      playbackSpeeds: AppConstants.playbackSpeeds,
    );
    duration.value = videoController!.value.duration;
    videoController!.addListener(_onVideoTick);
    isReady.value = true;
    _startPositionSaveTimer();
  }

  void _onVideoTick() {
    final value = videoController!.value;
    position.value = value.position;
    isPlaying.value = value.isPlaying;
  }

  Future<void> _initAudio() async {
    await audioPlayer.setFilePath(media.path);
    await audioPlayer.setSpeed(playbackSpeed.value);
    duration.value = audioPlayer.duration ?? Duration.zero;
    final resumeAt = _settingsService.rememberPosition ? _settingsService.getPlaybackPosition(media.id) : null;
    if (resumeAt != null && resumeAt < duration.value) {
      await audioPlayer.seek(resumeAt);
    }
    audioPlayer.positionStream.listen((p) => position.value = p);
    audioPlayer.playingStream.listen((p) => isPlaying.value = p);
    isReady.value = true;
    _startPositionSaveTimer();
    if (_settingsService.autoplayAudio) {
      await audioPlayer.play();
    }
  }

  /// Persists the current position every few seconds so playback can resume
  /// where the user left off (gated on the "Remember Position" setting).
  Timer? _positionSaveTimer;
  void _startPositionSaveTimer() {
    _positionSaveTimer = Timer.periodic(const Duration(seconds: 3), (_) => _savePosition());
  }

  Future<void> _savePosition() async {
    if (!_settingsService.rememberPosition) return;
    final current = position.value;
    final total = duration.value;
    // Close enough to the end — treat as finished, don't leave a stale
    // near-the-end resume point next time it's opened.
    if (total > Duration.zero && total - current < const Duration(seconds: 3)) {
      await _settingsService.clearPlaybackPosition(media.id);
    } else if (current > Duration.zero) {
      await _settingsService.savePlaybackPosition(media.id, current);
    }
  }

  Future<void> togglePlay() async {
    if (media.type == MediaType.video) {
      if (videoController!.value.isPlaying) {
        await videoController!.pause();
      } else {
        await videoController!.play();
      }
    } else {
      if (audioPlayer.playing) {
        await audioPlayer.pause();
      } else {
        await audioPlayer.play();
      }
    }
  }

  Future<void> seek(Duration to) async {
    if (media.type == MediaType.video) {
      await videoController!.seekTo(to);
    } else {
      await audioPlayer.seek(to);
    }
  }

  Future<void> setSpeed(double speed) async {
    playbackSpeed.value = speed;
    if (media.type == MediaType.video) {
      await videoController!.setPlaybackSpeed(speed);
    } else {
      await audioPlayer.setSpeed(speed);
    }
  }

  void setSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    sleepTimerRemaining.value = duration;
    _positionTicker?.cancel();
    _positionTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = sleepTimerRemaining.value;
      if (remaining == null) return;
      final next = remaining - const Duration(seconds: 1);
      if (next.isNegative || next == Duration.zero) {
        if (media.type == MediaType.audio) {
          audioPlayer.pause();
        } else {
          videoController?.pause();
        }
        sleepTimerRemaining.value = null;
        _positionTicker?.cancel();
      } else {
        sleepTimerRemaining.value = next;
      }
    });
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _positionTicker?.cancel();
    sleepTimerRemaining.value = null;
  }

  @override
  void onClose() {
    _positionSaveTimer?.cancel();
    unawaited(_savePosition());
    _sleepTimer?.cancel();
    _positionTicker?.cancel();
    videoController?.removeListener(_onVideoTick);
    chewieController?.dispose();
    videoController?.dispose();
    audioPlayer.dispose();
    super.onClose();
  }
}
