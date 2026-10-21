import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flick/l10n/l10n.dart';

/// Saves generated images to the device gallery.
class GallerySaveService {
  static const MethodChannel _channel = MethodChannel(
    'com.mossapps.flick/storage',
  );

  Future<String> saveImage({
    required Uint8List bytes,
    required String fileName,
    String albumName = 'Flick',
    bool retryOnPermissionRequest = true,
  }) async {
    if (!Platform.isAndroid) {
      throw GallerySaveException(l10n.savingRecapAndroidOnly);
    }

    try {
      final savedUri = await _channel.invokeMethod<String>(
        'saveImageToGallery',
        {'bytes': bytes, 'fileName': fileName, 'albumName': albumName},
      );

      if (savedUri == null || savedUri.isEmpty) {
        throw GallerySaveException(l10n.androidDidNotReturnGalleryPath);
      }

      return savedUri;
    } on PlatformException catch (error) {
      if (error.code == 'STORAGE_PERMISSION_REQUIRED' &&
          retryOnPermissionRequest) {
        final status = await Permission.storage.request();
        if (status.isGranted) {
          return saveImage(
            bytes: bytes,
            fileName: fileName,
            albumName: albumName,
            retryOnPermissionRequest: false,
          );
        }

        throw GallerySaveException(l10n.storagePermissionRequiredForRecap);
      }

      throw GallerySaveException(
        error.message ?? l10n.failedToSaveTheRecapImage,
      );
    }
  }
}

class GallerySaveException implements Exception {
  final String message;

  const GallerySaveException(this.message);

  @override
  String toString() => 'GallerySaveException: $message';
}
