import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

final permissionProvider = FutureProvider<bool>((ref) async {
  if (Platform.isAndroid) {
    // Check if we're on Android 13+ (API 33+) where READ_MEDIA_AUDIO is required
    final audioPermission = await Permission.audio.status;
    if (audioPermission.isDenied || audioPermission.isPermanentlyDenied) {
      final result = await Permission.audio.request();
      if (result.isGranted) return true;
    } else if (audioPermission.isGranted) {
      return true;
    }

    // For Android < 13 where READ_EXTERNAL_STORAGE is required
    final storagePermission = await Permission.storage.status;
    if (storagePermission.isDenied || storagePermission.isPermanentlyDenied) {
      final result = await Permission.storage.request();
      if (result.isGranted) return true;
    } else if (storagePermission.isGranted) {
      return true;
    }
    
    return false;
  }
  return true; // We assume true for iOS or other platforms for now
});
