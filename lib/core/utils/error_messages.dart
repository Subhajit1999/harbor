import 'dart:io';
import 'package:dio/dio.dart';

/// Maps the error shapes that actually occur in the download/resolve
/// pipeline to short, non-technical strings — used anywhere an error
/// message ends up directly in front of the user (DownloadCard,
/// snackbars), so they see "No internet connection" instead of a raw
/// `DioException [connection error]: ...` stack dump.
String friendlyMessage(Object error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timed out. The source may be slow — try again.';
      case DioExceptionType.connectionError:
        return 'No internet connection. Check your network and try again.';
      case DioExceptionType.badResponse:
        final code = error.response?.statusCode;
        if (code == 401 || code == 403) return 'Access denied by the server.';
        if (code == 404) return 'The file is no longer available at its source.';
        if (code != null && code >= 500) return 'The server had a problem. Try again shortly.';
        return 'The download failed to start (server error).';
      case DioExceptionType.cancel:
        return 'Canceled.';
      default:
        return 'A network error interrupted the download.';
    }
  }
  if (error is SocketException) {
    return 'No internet connection. Check your network and try again.';
  }
  if (error is FileSystemException) {
    // Common real cause on iOS/Android alike when a download fills the disk.
    if (error.osError?.errorCode == 28 /* ENOSPC */ ||
        (error.message.toLowerCase().contains('space'))) {
      return 'Not enough storage space on your device.';
    }
    return 'A file could not be written to storage.';
  }
  return 'Something went wrong. Try again.';
}
