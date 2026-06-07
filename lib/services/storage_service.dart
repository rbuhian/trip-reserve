import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/document.dart';
import '../models/vehicle.dart';
import '../providers/supabase_provider.dart';

/// Storage buckets
class StorageBuckets {
  static const String vehiclePhotos = 'vehicle-photos';
  static const String documents = 'documents';
  static const String avatars = 'avatars';
}

/// File size limits
class FileSizeLimits {
  /// Max size for vehicle photos: 5 MB
  static const int vehiclePhoto = 5 * 1024 * 1024;

  /// Max size for documents: 10 MB
  static const int document = 10 * 1024 * 1024;

  /// Max size for avatars: 2 MB
  static const int avatar = 2 * 1024 * 1024;

  /// Human-readable size text
  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Exception for file size exceeded
class FileSizeExceededException implements Exception {
  final int fileSize;
  final int maxSize;
  final String fileType;

  FileSizeExceededException({
    required this.fileSize,
    required this.maxSize,
    required this.fileType,
  });

  @override
  String toString() =>
      '$fileType exceeds maximum size of ${FileSizeLimits.formatSize(maxSize)}. '
      'Your file is ${FileSizeLimits.formatSize(fileSize)}.';
}

/// Storage service for file uploads
class StorageService {
  final SupabaseClient _client;
  final _uuid = const Uuid();

  StorageService(this._client);

  /// Upload a vehicle photo
  ///
  /// Throws [FileSizeExceededException] if file exceeds 5 MB limit.
  Future<UploadResult> uploadVehiclePhoto({
    required String vehicleId,
    required VehiclePhotoType photoType,
    required XFile file,
  }) async {
    final bytes = await file.readAsBytes();

    // Check file size limit
    if (bytes.length > FileSizeLimits.vehiclePhoto) {
      throw FileSizeExceededException(
        fileSize: bytes.length,
        maxSize: FileSizeLimits.vehiclePhoto,
        fileType: 'Vehicle photo',
      );
    }

    final ext = path.extension(file.name).toLowerCase();
    final fileName = '${_uuid.v4()}$ext';
    final storagePath = 'vehicles/$vehicleId/${photoType.value}/$fileName';

    await _client.storage
        .from(StorageBuckets.vehiclePhotos)
        .uploadBinary(storagePath, bytes, fileOptions: FileOptions(
          contentType: _getMimeType(ext),
          upsert: true,
        ));

    final url = _client.storage
        .from(StorageBuckets.vehiclePhotos)
        .getPublicUrl(storagePath);

    return UploadResult(
      storagePath: storagePath,
      url: url,
      fileName: file.name,
      fileSize: bytes.length,
      mimeType: _getMimeType(ext),
    );
  }

  /// Upload a document (driver's license, OR/CR)
  ///
  /// Throws [FileSizeExceededException] if file exceeds 10 MB limit.
  Future<UploadResult> uploadDocument({
    required String userId,
    required DocumentType documentType,
    required XFile file,
    String? vehicleId,
  }) async {
    final bytes = await file.readAsBytes();

    // Check file size limit
    if (bytes.length > FileSizeLimits.document) {
      throw FileSizeExceededException(
        fileSize: bytes.length,
        maxSize: FileSizeLimits.document,
        fileType: documentType.displayName,
      );
    }

    final ext = path.extension(file.name).toLowerCase();
    final fileName = '${_uuid.v4()}$ext';

    String storagePath;
    if (documentType.isVehicleDocument && vehicleId != null) {
      storagePath = 'vehicles/$vehicleId/${documentType.value}/$fileName';
    } else {
      storagePath = 'users/$userId/${documentType.value}/$fileName';
    }

    await _client.storage
        .from(StorageBuckets.documents)
        .uploadBinary(storagePath, bytes, fileOptions: FileOptions(
          contentType: _getMimeType(ext),
          upsert: true,
        ));

    // Get signed URL for private bucket (valid for 1 year)
    final url = await _client.storage
        .from(StorageBuckets.documents)
        .createSignedUrl(storagePath, 60 * 60 * 24 * 365);

    return UploadResult(
      storagePath: storagePath,
      url: url,
      fileName: file.name,
      fileSize: bytes.length,
      mimeType: _getMimeType(ext),
    );
  }

  /// Upload a user avatar
  ///
  /// Throws [FileSizeExceededException] if file exceeds 2 MB limit.
  Future<UploadResult> uploadAvatar({
    required String userId,
    required XFile file,
  }) async {
    final bytes = await file.readAsBytes();

    // Check file size limit
    if (bytes.length > FileSizeLimits.avatar) {
      throw FileSizeExceededException(
        fileSize: bytes.length,
        maxSize: FileSizeLimits.avatar,
        fileType: 'Avatar image',
      );
    }

    final ext = path.extension(file.name).toLowerCase();
    final fileName = '${_uuid.v4()}$ext';
    final storagePath = '$userId/$fileName';

    await _client.storage
        .from(StorageBuckets.avatars)
        .uploadBinary(storagePath, bytes, fileOptions: FileOptions(
          contentType: _getMimeType(ext),
          upsert: true,
        ));

    final url = _client.storage
        .from(StorageBuckets.avatars)
        .getPublicUrl(storagePath);

    return UploadResult(
      storagePath: storagePath,
      url: url,
      fileName: file.name,
      fileSize: bytes.length,
      mimeType: _getMimeType(ext),
    );
  }

  /// Delete avatar
  Future<void> deleteAvatar(String storagePath) async {
    await deleteFile(StorageBuckets.avatars, storagePath);
  }

  /// Upload from bytes (for web/cross-platform)
  Future<UploadResult> uploadBytes({
    required String bucket,
    required String storagePath,
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    final ext = path.extension(fileName).toLowerCase();
    final contentType = mimeType ?? _getMimeType(ext);

    await _client.storage
        .from(bucket)
        .uploadBinary(storagePath, bytes, fileOptions: FileOptions(
          contentType: contentType,
          upsert: true,
        ));

    String url;
    if (bucket == StorageBuckets.vehiclePhotos) {
      url = _client.storage.from(bucket).getPublicUrl(storagePath);
    } else {
      url = await _client.storage
          .from(bucket)
          .createSignedUrl(storagePath, 60 * 60 * 24 * 365);
    }

    return UploadResult(
      storagePath: storagePath,
      url: url,
      fileName: fileName,
      fileSize: bytes.length,
      mimeType: contentType,
    );
  }

  /// Delete a file from storage
  Future<void> deleteFile(String bucket, String storagePath) async {
    await _client.storage.from(bucket).remove([storagePath]);
  }

  /// Delete vehicle photo
  Future<void> deleteVehiclePhoto(String storagePath) async {
    await deleteFile(StorageBuckets.vehiclePhotos, storagePath);
  }

  /// Delete document
  Future<void> deleteDocument(String storagePath) async {
    await deleteFile(StorageBuckets.documents, storagePath);
  }

  /// Get MIME type from file extension
  String _getMimeType(String ext) {
    switch (ext.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.pdf':
        return 'application/pdf';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  /// Generate a unique file path
  String generatePath({
    required String folder,
    required String subfolder,
    required String extension,
  }) {
    final fileName = '${_uuid.v4()}$extension';
    return '$folder/$subfolder/$fileName';
  }
}

/// Result of a file upload
class UploadResult {
  final String storagePath;
  final String url;
  final String fileName;
  final int fileSize;
  final String? mimeType;

  const UploadResult({
    required this.storagePath,
    required this.url,
    required this.fileName,
    required this.fileSize,
    this.mimeType,
  });
}

/// Provider for StorageService
final storageServiceProvider = Provider<StorageService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return StorageService(client);
});

/// Image picker helper
class ImagePickerHelper {
  static final ImagePicker _picker = ImagePicker();

  /// Pick a vehicle photo from gallery or camera
  ///
  /// Resized to max 1920x1080, compressed to ~85% quality.
  /// Target size: under 5 MB.
  static Future<XFile?> pickImage({
    ImageSource source = ImageSource.gallery,
    int maxWidth = 1920,
    int maxHeight = 1080,
    int imageQuality = 85,
  }) async {
    return await _picker.pickImage(
      source: source,
      maxWidth: maxWidth.toDouble(),
      maxHeight: maxHeight.toDouble(),
      imageQuality: imageQuality,
    );
  }

  /// Pick multiple vehicle photos from gallery
  static Future<List<XFile>> pickMultipleImages({
    int maxWidth = 1920,
    int maxHeight = 1080,
    int imageQuality = 85,
  }) async {
    return await _picker.pickMultiImage(
      maxWidth: maxWidth.toDouble(),
      maxHeight: maxHeight.toDouble(),
      imageQuality: imageQuality,
    );
  }

  /// Pick a document image (OR, CR, License)
  ///
  /// Higher resolution (2400x2400) and quality (95%) for legibility.
  /// Target size: under 10 MB.
  static Future<XFile?> pickDocument() async {
    return await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2400,
      maxHeight: 2400,
      imageQuality: 95, // Higher quality for documents
    );
  }

  /// Pick a document from camera (for scanning)
  static Future<XFile?> scanDocument() async {
    return await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 2400,
      maxHeight: 2400,
      imageQuality: 95,
    );
  }

  /// Pick an avatar image
  ///
  /// Square aspect ratio optimized, compressed to ~80% quality.
  /// Target size: under 2 MB.
  static Future<XFile?> pickAvatar({
    ImageSource source = ImageSource.gallery,
  }) async {
    return await _picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
  }

  /// Get file size limit message
  static String getFileSizeInfo(bool isDocument) {
    if (isDocument) {
      return 'Max file size: ${FileSizeLimits.formatSize(FileSizeLimits.document)}';
    }
    return 'Max file size: ${FileSizeLimits.formatSize(FileSizeLimits.vehiclePhoto)}';
  }
}
