import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme/app_colors.dart';
import '../models/document.dart';

/// Info text about document requirements
const String kDocumentInfo =
    'Upload clear photos or scans of your documents. Max 10 MB per file.';

/// Card for uploading a document (OR, CR, License)
class DocumentUploadCard extends StatelessWidget {
  final DocumentType documentType;
  final Document? currentDocument;
  final XFile? pendingFile;
  final bool isUploading;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onView;

  const DocumentUploadCard({
    super.key,
    required this.documentType,
    this.currentDocument,
    this.pendingFile,
    this.isUploading = false,
    this.onTap,
    this.onDelete,
    this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasDocument = currentDocument != null || pendingFile != null;

    return GestureDetector(
      onTap: isUploading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _getBorderColor(colorScheme),
            width: hasDocument ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Icon/Preview
            _buildLeading(colorScheme),
            const SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    documentType.displayName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildSubtitle(colorScheme),
                ],
              ),
            ),

            // Actions
            if (isUploading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (hasDocument)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onView != null)
                    IconButton(
                      icon: Icon(
                        Icons.visibility_outlined,
                        color: colorScheme.primary,
                      ),
                      onPressed: onView,
                      tooltip: 'View',
                    ),
                  if (onDelete != null)
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: colorScheme.error,
                      ),
                      onPressed: onDelete,
                      tooltip: 'Remove',
                    ),
                ],
              )
            else
              Icon(
                Icons.upload_file,
                color: colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }

  Color _getBorderColor(ColorScheme colorScheme) {
    if (currentDocument != null) {
      switch (currentDocument!.status) {
        case DocumentStatus.approved:
          return AppColors.success;
        case DocumentStatus.rejected:
          return colorScheme.error;
        case DocumentStatus.expired:
          return AppColors.warning;
        case DocumentStatus.pending:
          return AppColors.info;
      }
    }
    if (pendingFile != null) {
      return colorScheme.primary;
    }
    return colorScheme.outlineVariant.withOpacity(0.5);
  }

  Widget _buildLeading(ColorScheme colorScheme) {
    if (pendingFile != null) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          image: DecorationImage(
            image: FileImage(File(pendingFile!.path)),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    if (currentDocument != null) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _getStatusColor(currentDocument!.status).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          _getStatusIcon(currentDocument!.status),
          color: _getStatusColor(currentDocument!.status),
        ),
      );
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.description_outlined,
        color: colorScheme.primary,
      ),
    );
  }

  Widget _buildSubtitle(ColorScheme colorScheme) {
    if (pendingFile != null) {
      return Text(
        'Ready to upload',
        style: TextStyle(
          fontSize: 13,
          color: colorScheme.primary,
        ),
      );
    }

    if (currentDocument != null) {
      final doc = currentDocument!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(doc.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  doc.status.displayName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _getStatusColor(doc.status),
                  ),
                ),
              ),
              if (doc.isExpiringSoon && doc.status == DocumentStatus.approved) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.warning_amber,
                  size: 14,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 4),
                Text(
                  'Expiring soon',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ],
          ),
          if (doc.rejectionReason != null && doc.status == DocumentStatus.rejected) ...[
            const SizedBox(height: 4),
            Text(
              doc.rejectionReason!,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.error,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      );
    }

    return Text(
      'Tap to upload',
      style: TextStyle(
        fontSize: 13,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }

  Color _getStatusColor(DocumentStatus status) {
    switch (status) {
      case DocumentStatus.approved:
        return AppColors.success;
      case DocumentStatus.rejected:
        return AppColors.error;
      case DocumentStatus.expired:
        return AppColors.warning;
      case DocumentStatus.pending:
        return AppColors.info;
    }
  }

  IconData _getStatusIcon(DocumentStatus status) {
    switch (status) {
      case DocumentStatus.approved:
        return Icons.check_circle;
      case DocumentStatus.rejected:
        return Icons.cancel;
      case DocumentStatus.expired:
        return Icons.schedule;
      case DocumentStatus.pending:
        return Icons.hourglass_empty;
    }
  }
}

/// List of document upload cards for a vehicle
class VehicleDocumentsList extends StatelessWidget {
  final Document? orDocument;
  final Document? crDocument;
  final XFile? pendingOr;
  final XFile? pendingCr;
  final bool isUploadingOr;
  final bool isUploadingCr;
  final VoidCallback? onOrTap;
  final VoidCallback? onCrTap;
  final VoidCallback? onOrDelete;
  final VoidCallback? onCrDelete;
  final VoidCallback? onOrView;
  final VoidCallback? onCrView;

  const VehicleDocumentsList({
    super.key,
    this.orDocument,
    this.crDocument,
    this.pendingOr,
    this.pendingCr,
    this.isUploadingOr = false,
    this.isUploadingCr = false,
    this.onOrTap,
    this.onCrTap,
    this.onOrDelete,
    this.onCrDelete,
    this.onOrView,
    this.onCrView,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DocumentUploadCard(
          documentType: DocumentType.vehicleOr,
          currentDocument: orDocument,
          pendingFile: pendingOr,
          isUploading: isUploadingOr,
          onTap: onOrTap,
          onDelete: onOrDelete,
          onView: onOrView,
        ),
        const SizedBox(height: 12),
        DocumentUploadCard(
          documentType: DocumentType.vehicleCr,
          currentDocument: crDocument,
          pendingFile: pendingCr,
          isUploading: isUploadingCr,
          onTap: onCrTap,
          onDelete: onCrDelete,
          onView: onCrView,
        ),
      ],
    );
  }
}
