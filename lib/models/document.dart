import 'package:freezed_annotation/freezed_annotation.dart';

part 'document.freezed.dart';
part 'document.g.dart';

/// Document types
enum DocumentType {
  @JsonValue('drivers_license')
  driversLicense,
  @JsonValue('vehicle_or')
  vehicleOr,
  @JsonValue('vehicle_cr')
  vehicleCr;

  String get displayName {
    switch (this) {
      case DocumentType.driversLicense:
        return "Driver's License";
      case DocumentType.vehicleOr:
        return 'Official Receipt (OR)';
      case DocumentType.vehicleCr:
        return 'Certificate of Registration (CR)';
    }
  }

  String get value {
    switch (this) {
      case DocumentType.driversLicense:
        return 'drivers_license';
      case DocumentType.vehicleOr:
        return 'vehicle_or';
      case DocumentType.vehicleCr:
        return 'vehicle_cr';
    }
  }

  bool get isVehicleDocument =>
      this == DocumentType.vehicleOr || this == DocumentType.vehicleCr;
}

/// Document status
enum DocumentStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('approved')
  approved,
  @JsonValue('rejected')
  rejected,
  @JsonValue('expired')
  expired;

  String get displayName {
    switch (this) {
      case DocumentStatus.pending:
        return 'Pending Review';
      case DocumentStatus.approved:
        return 'Approved';
      case DocumentStatus.rejected:
        return 'Rejected';
      case DocumentStatus.expired:
        return 'Expired';
    }
  }

  bool get isValid => this == DocumentStatus.approved;
}

/// Document model
@freezed
abstract class Document with _$Document {
  const factory Document({
    required String id,
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'vehicle_id') String? vehicleId,
    @JsonKey(name: 'document_type') required DocumentType documentType,
    required DocumentStatus status,
    @JsonKey(name: 'storage_path') required String storagePath,
    required String url,
    @JsonKey(name: 'file_name') required String fileName,
    @JsonKey(name: 'file_size') int? fileSize,
    @JsonKey(name: 'mime_type') String? mimeType,
    @JsonKey(name: 'document_number') String? documentNumber,
    @JsonKey(name: 'expiry_date') DateTime? expiryDate,
    @JsonKey(name: 'reviewed_by') String? reviewedBy,
    @JsonKey(name: 'reviewed_at') DateTime? reviewedAt,
    @JsonKey(name: 'rejection_reason') String? rejectionReason,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _Document;

  const Document._();

  factory Document.fromJson(Map<String, dynamic> json) =>
      _$DocumentFromJson(json);

  /// Check if document is expired
  bool get isExpired {
    if (expiryDate == null) return false;
    return DateTime.now().isAfter(expiryDate!);
  }

  /// Days until expiry (negative if expired)
  int? get daysUntilExpiry {
    if (expiryDate == null) return null;
    return expiryDate!.difference(DateTime.now()).inDays;
  }

  /// Check if document is expiring soon (within 30 days)
  bool get isExpiringSoon {
    final days = daysUntilExpiry;
    return days != null && days >= 0 && days <= 30;
  }

  /// File size in human-readable format
  String get fileSizeText {
    if (fileSize == null) return '-';
    if (fileSize! < 1024) return '$fileSize B';
    if (fileSize! < 1024 * 1024) return '${(fileSize! / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Data for uploading a document
@freezed
abstract class DocumentUpload with _$DocumentUpload {
  const factory DocumentUpload({
    @JsonKey(name: 'document_type') required DocumentType documentType,
    @JsonKey(name: 'vehicle_id') String? vehicleId,
    @JsonKey(name: 'storage_path') required String storagePath,
    required String url,
    @JsonKey(name: 'file_name') required String fileName,
    @JsonKey(name: 'file_size') int? fileSize,
    @JsonKey(name: 'mime_type') String? mimeType,
    @JsonKey(name: 'document_number') String? documentNumber,
    @JsonKey(name: 'expiry_date') DateTime? expiryDate,
  }) = _DocumentUpload;

  factory DocumentUpload.fromJson(Map<String, dynamic> json) =>
      _$DocumentUploadFromJson(json);
}
