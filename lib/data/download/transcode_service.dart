import 'dart:io';
import 'package:ffmpeg_kit_flutter_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/return_code.dart';
import 'package:path/path.dart' as p;
import '../../core/utils/app_logger.dart';

class TranscodeService {
  static const _tag = 'TranscodeService';

  /// Examines the file at [path]. If its video codec is unsupported by iOS
  /// (like AV1 or VP9), it transcodes the file to H.264 using the hardware
  /// encoder and returns the new file path. Otherwise, returns the original path.
  Future<String> ensureIosCompatibility(String path) async {
    final session = await FFprobeKit.getMediaInformation(path);
    final info = session.getMediaInformation();
    
    if (info == null) {
      AppLogger.w(_tag, 'Failed to get media information for $path. Skipping transcode check.');
      return path;
    }

    bool needsTranscode = false;
    final streams = info.getStreams();
    for (final stream in streams) {
      if (stream.getType() == 'video') {
        final codec = stream.getCodec()?.toLowerCase() ?? '';
        // iOS supported codecs: h264, hevc. 
        if (codec.contains('vp9') || codec.contains('vp8') || codec.contains('av1') || codec.contains('av01')) {
          needsTranscode = true;
          break;
        }
      }
    }

    if (!needsTranscode) {
      AppLogger.i(_tag, 'File $path is already iOS compatible.');
      return path;
    }

    AppLogger.i(_tag, 'Unsupported codec detected in $path. Transcoding to H.264...');
    final ext = p.extension(path);
    final outPath = path.replaceAll(ext, '_transcoded.mp4');

    // Transcode using VideoToolbox for hardware acceleration (fast, battery efficient)
    final command = '-y -i "$path" -c:v h264_videotoolbox -c:a aac -b:v 4000k "$outPath"';
    
    final execSession = await FFmpegKit.execute(command);
    final returnCode = await execSession.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      AppLogger.i(_tag, 'Transcode successful: $outPath');
      try {
        await File(path).delete(); // Cleanup original
      } catch (e) {
        AppLogger.w(_tag, 'Failed to delete original file after transcode: $e');
      }
      return outPath;
    } else {
      final logs = await execSession.getAllLogsAsString();
      AppLogger.e(_tag, 'Transcode failed with return code ${returnCode?.getValue()}:\n$logs');
      throw Exception('Failed to transcode media for iOS compatibility.');
    }
  }
}
