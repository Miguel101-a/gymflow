import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_colors.dart';

class AvatarUploader {
  static const _allowedExtensions = {'png', 'jpg', 'jpeg'};
  static const _rejectedExtensions = {'heic', 'heif'};
  static const _minTargetBytes = 200 * 1024;
  static const _maxTargetBytes = 500 * 1024;
  static const _maxInputBytes = 15 * 1024 * 1024;
  static const _outputSize = 512;

  static Future<String?> pickCropCompressUpload(BuildContext context) async {
    final picker = ImagePicker();
    final XFile? picked;
    try {
      picked = await picker.pickImage(source: ImageSource.gallery);
    } catch (e) {
      _showError(context, 'No se pudo abrir el selector de imágenes.');
      return null;
    }
    if (picked == null) return null;

    final ext = picked.name.split('.').last.toLowerCase();
    if (_rejectedExtensions.contains(ext)) {
      _showError(context, 'Formato HEIC no compatible. Usa PNG, JPG o JPEG.');
      return null;
    }
    if (!_allowedExtensions.contains(ext)) {
      _showError(context, 'Formato no compatible. Usa PNG, JPG o JPEG.');
      return null;
    }

    final originalBytes = await picked.readAsBytes();
    if (originalBytes.lengthInBytes > _maxInputBytes) {
      _showError(context, 'La imagen es demasiado grande (máx. 15 MB).');
      return null;
    }

    if (img.decodeImage(originalBytes) == null) {
      _showError(context, 'No se pudo leer la imagen.');
      return null;
    }

    if (!context.mounted) return null;
    final cropped = await _showCropDialog(context, originalBytes);
    if (cropped == null) return null;

    final compressed = _compressToTarget(cropped);
    if (compressed == null) {
      if (context.mounted) {
        _showError(context, 'No se pudo procesar la imagen.');
      }
      return null;
    }

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (context.mounted) {
        _showError(context, 'Sesión expirada. Inicia sesión de nuevo.');
      }
      return null;
    }

    try {
      final path = '${user.id}/profile.jpg';
      await supabase.storage.from('avatars').uploadBinary(
            path,
            compressed,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
              cacheControl: '3600',
            ),
          );

      final publicUrl = supabase.storage.from('avatars').getPublicUrl(path);
      final cacheBustedUrl = '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';

      await supabase
          .from('perfiles')
          .update({
            'avatar_url': cacheBustedUrl,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', user.id);

      return cacheBustedUrl;
    } catch (e) {
      if (context.mounted) {
        _showError(context, 'Error al subir la foto: $e');
      }
      return null;
    }
  }

  static Future<Uint8List?> _showCropDialog(
    BuildContext context,
    Uint8List sourceBytes,
  ) {
    final cropController = CropController();
    Uint8List? result;

    return showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: SizedBox(
            width: 480,
            height: 600,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Recortar foto (1:1)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Crop(
                    image: sourceBytes,
                    controller: cropController,
                    aspectRatio: 1,
                    withCircleUi: false,
                    baseColor: AppColors.backgroundLight,
                    maskColor: Colors.black.withValues(alpha: 0.5),
                    onCropped: (cropResult) {
                      switch (cropResult) {
                        case CropSuccess(:final croppedImage):
                          result = croppedImage;
                          Navigator.of(dialogContext).pop(croppedImage);
                        case CropFailure():
                          Navigator.of(dialogContext).pop();
                      }
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => cropController.crop(),
                          child: const Text('Recortar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) => result);
  }

  static Uint8List? _compressToTarget(Uint8List croppedBytes) {
    final decoded = img.decodeImage(croppedBytes);
    if (decoded == null) return null;

    final resized = img.copyResize(
      decoded,
      width: _outputSize,
      height: _outputSize,
      interpolation: img.Interpolation.cubic,
    );

    int quality = 85;
    Uint8List output = Uint8List.fromList(img.encodeJpg(resized, quality: quality));

    while (output.lengthInBytes > _maxTargetBytes && quality > 30) {
      quality -= 10;
      output = Uint8List.fromList(img.encodeJpg(resized, quality: quality));
    }

    if (output.lengthInBytes < _minTargetBytes && quality < 95) {
      int upQuality = quality;
      while (output.lengthInBytes < _minTargetBytes && upQuality < 95) {
        upQuality += 5;
        final candidate = Uint8List.fromList(img.encodeJpg(resized, quality: upQuality));
        if (candidate.lengthInBytes > _maxTargetBytes) break;
        output = candidate;
      }
    }

    return output;
  }

  static void _showError(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }
}
