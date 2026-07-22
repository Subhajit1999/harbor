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
    audioPlayer.positionStream.listen((p) => position.value = p);
    audioPlayer.playingStream.listen((p) => isPlaying.value = p);
    isReady.value = true;
    if (_settingsService.autoResume) {
      await audioPlayer.play();
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
    _sleepTimer?.cancel();
    _positionTicker?.cancel();
    videoController?.removeListener(_onVideoTick);
    chewieController?.dispose();
    videoController?.dispose();
    audioPlayer.dispose();
    super.onClose();
  }
}
