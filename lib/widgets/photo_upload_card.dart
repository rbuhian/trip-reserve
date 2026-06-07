import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme/app_colors.dart';
import '../models/vehicle.dart';
import '../services/storage_service.dart';

/// Info text about photo requirements
const String kVehiclePhotoInfo =
    'Upload clear photos of your vehicle. Max 5 MB per photo.';

/// Card for uploading a vehicle photo
class PhotoUploadCard extends StatelessWidget {
  final VehiclePhotoType photoType;
  final String? currentUrl;
  final XFile? pendingFile;
  final bool isUploading;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const PhotoUploadCard({
    super.key,
    required this.photoType,
    this.currentUrl,
    this.pendingFile,
    this.isUploading = false,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasImage = currentUrl != null || pendingFile != null;

    return GestureDetector(
      onTap: isUploading ? null : onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasImage
                ? colorScheme.primary.withOpacity(0.5)
                : colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
        child: Stack(
          children: [
            // Image preview
            if (pendingFile != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Image.file(
                  File(pendingFile!.path),
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                ),
              )
            else if (currentUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Image.network(
                  currentUrl!,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildPlaceholder(colorScheme),
                ),
              )
            else
              _buildPlaceholder(colorScheme),

            // Loading overlay
            if (isUploading)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

            // Delete button
            if (hasImage && !isUploading && onDelete != null)
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

            // Label
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(11),
                  ),
                ),
                child: Text(
                  photoType.displayName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_a_photo_outlined,
            size: 28,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 4),
          Text(
            photoType.displayName,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Grid of vehicle photo upload cards
class VehiclePhotoGrid extends StatelessWidget {
  final Map<VehiclePhotoType, String?> currentUrls;
  final Map<VehiclePhotoType, XFile?> pendingFiles;
  final Set<VehiclePhotoType> uploadingTypes;
  final ValueChanged<VehiclePhotoType> onPhotoTap;
  final ValueChanged<VehiclePhotoType>? onPhotoDelete;

  const VehiclePhotoGrid({
    super.key,
    required this.currentUrls,
    required this.pendingFiles,
    required this.uploadingTypes,
    required this.onPhotoTap,
    this.onPhotoDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1: Front, Back
        Row(
          children: [
            Expanded(
              child: PhotoUploadCard(
                photoType: VehiclePhotoType.front,
                currentUrl: currentUrls[VehiclePhotoType.front],
                pendingFile: pendingFiles[VehiclePhotoType.front],
                isUploading: uploadingTypes.contains(VehiclePhotoType.front),
                onTap: () => onPhotoTap(VehiclePhotoType.front),
                onDelete: onPhotoDelete != null
                    ? () => onPhotoDelete!(VehiclePhotoType.front)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PhotoUploadCard(
                photoType: VehiclePhotoType.back,
                currentUrl: currentUrls[VehiclePhotoType.back],
                pendingFile: pendingFiles[VehiclePhotoType.back],
                isUploading: uploadingTypes.contains(VehiclePhotoType.back),
                onTap: () => onPhotoTap(VehiclePhotoType.back),
                onDelete: onPhotoDelete != null
                    ? () => onPhotoDelete!(VehiclePhotoType.back)
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Row 2: Left, Right
        Row(
          children: [
            Expanded(
              child: PhotoUploadCard(
                photoType: VehiclePhotoType.left,
                currentUrl: currentUrls[VehiclePhotoType.left],
                pendingFile: pendingFiles[VehiclePhotoType.left],
                isUploading: uploadingTypes.contains(VehiclePhotoType.left),
                onTap: () => onPhotoTap(VehiclePhotoType.left),
                onDelete: onPhotoDelete != null
                    ? () => onPhotoDelete!(VehiclePhotoType.left)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PhotoUploadCard(
                photoType: VehiclePhotoType.right,
                currentUrl: currentUrls[VehiclePhotoType.right],
                pendingFile: pendingFiles[VehiclePhotoType.right],
                isUploading: uploadingTypes.contains(VehiclePhotoType.right),
                onTap: () => onPhotoTap(VehiclePhotoType.right),
                onDelete: onPhotoDelete != null
                    ? () => onPhotoDelete!(VehiclePhotoType.right)
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Row 3: Interior (full width)
        PhotoUploadCard(
          photoType: VehiclePhotoType.interior,
          currentUrl: currentUrls[VehiclePhotoType.interior],
          pendingFile: pendingFiles[VehiclePhotoType.interior],
          isUploading: uploadingTypes.contains(VehiclePhotoType.interior),
          onTap: () => onPhotoTap(VehiclePhotoType.interior),
          onDelete: onPhotoDelete != null
              ? () => onPhotoDelete!(VehiclePhotoType.interior)
              : null,
        ),
      ],
    );
  }
}
