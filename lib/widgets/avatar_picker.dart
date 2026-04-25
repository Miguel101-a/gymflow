import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/avatar_uploader.dart';

class AvatarPicker extends StatefulWidget {
  final String? currentUrl;
  final double radius;
  final ValueChanged<String> onUpdated;
  final bool editable;

  const AvatarPicker({
    super.key,
    required this.currentUrl,
    required this.onUpdated,
    this.radius = 56,
    this.editable = true,
  });

  @override
  State<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<AvatarPicker> {
  bool _uploading = false;

  Future<void> _handleTap() async {
    if (_uploading) return;
    setState(() => _uploading = true);
    try {
      final newUrl = await AvatarUploader.pickCropCompressUpload(context);
      if (newUrl != null) {
        widget.onUpdated(newUrl);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto de perfil actualizada'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUrl = widget.currentUrl != null && widget.currentUrl!.isNotEmpty;
    final iconSize = widget.radius;

    return GestureDetector(
      onTap: widget.editable ? _handleTap : null,
      child: Stack(
        children: [
          CircleAvatar(
            radius: widget.radius,
            backgroundColor: AppColors.chipBackground,
            backgroundImage: hasUrl ? NetworkImage(widget.currentUrl!) : null,
            child: !hasUrl
                ? Icon(Icons.person, size: iconSize, color: AppColors.primary)
                : null,
          ),
          if (widget.editable)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: _uploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : const Icon(
                        Icons.camera_alt,
                        color: AppColors.white,
                        size: 18,
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
