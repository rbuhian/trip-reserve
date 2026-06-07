import 'package:freezed_annotation/freezed_annotation.dart';

import 'user.dart';

part 'vehicle.freezed.dart';
part 'vehicle.g.dart';

/// Vehicle model
@freezed
abstract class Vehicle with _$Vehicle {
  const factory Vehicle({
    required String id,
    @JsonKey(name: 'driver_id') required String driverId,
    required String name,
    @JsonKey(name: 'plate_number') required String plateNumber,
    @Default(4) int capacity,
    int? year,
    String? model,
    String? color,
    @JsonKey(name: 'image_url') String? imageUrl,
    String? description,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,

    // Joined data (optional)
    UserRef? driver,
    @JsonKey(name: 'vehicle_photos') List<VehiclePhoto>? photos,
  }) = _Vehicle;

  const Vehicle._();

  factory Vehicle.fromJson(Map<String, dynamic> json) => _$VehicleFromJson(json);

  /// Display text: "Toyota Innova • ABC 1234"
  String get displayText => '$name • $plateNumber';

  /// Full vehicle description: "2023 Toyota Innova (White)"
  String get fullDescription {
    final parts = <String>[];
    if (year != null) parts.add(year.toString());
    parts.add(name);
    if (color != null) parts.add('($color)');
    return parts.join(' ');
  }

  /// Capacity text: "4 passengers"
  String get capacityText =>
      '$capacity ${capacity == 1 ? 'passenger' : 'passengers'}';

  /// Get photo URL by type
  String? getPhotoUrl(VehiclePhotoType type) {
    return photos?.firstWhere(
      (p) => p.photoType == type,
      orElse: () => const VehiclePhoto(id: '', vehicleId: '', photoType: VehiclePhotoType.front, storagePath: '', url: ''),
    ).url;
  }
}

/// Lightweight vehicle reference for lists
@freezed
abstract class VehicleRef with _$VehicleRef {
  const factory VehicleRef({
    required String id,
    required String name,
    @JsonKey(name: 'plate_number') required String plateNumber,
    @Default(4) int capacity,
    int? year,
    String? model,
    String? color,
    @JsonKey(name: 'image_url') String? imageUrl,
  }) = _VehicleRef;

  factory VehicleRef.fromJson(Map<String, dynamic> json) =>
      _$VehicleRefFromJson(json);
}

/// Vehicle photo types
enum VehiclePhotoType {
  @JsonValue('vehicle_photo_front')
  front,
  @JsonValue('vehicle_photo_back')
  back,
  @JsonValue('vehicle_photo_left')
  left,
  @JsonValue('vehicle_photo_right')
  right,
  @JsonValue('vehicle_photo_interior')
  interior;

  String get displayName {
    switch (this) {
      case VehiclePhotoType.front:
        return 'Front';
      case VehiclePhotoType.back:
        return 'Back';
      case VehiclePhotoType.left:
        return 'Left Side';
      case VehiclePhotoType.right:
        return 'Right Side';
      case VehiclePhotoType.interior:
        return 'Interior';
    }
  }

  String get value {
    switch (this) {
      case VehiclePhotoType.front:
        return 'vehicle_photo_front';
      case VehiclePhotoType.back:
        return 'vehicle_photo_back';
      case VehiclePhotoType.left:
        return 'vehicle_photo_left';
      case VehiclePhotoType.right:
        return 'vehicle_photo_right';
      case VehiclePhotoType.interior:
        return 'vehicle_photo_interior';
    }
  }
}

/// Vehicle photo model
@freezed
abstract class VehiclePhoto with _$VehiclePhoto {
  const factory VehiclePhoto({
    required String id,
    @JsonKey(name: 'vehicle_id') required String vehicleId,
    @JsonKey(name: 'photo_type') required VehiclePhotoType photoType,
    @JsonKey(name: 'storage_path') required String storagePath,
    required String url,
    @JsonKey(name: 'uploaded_at') DateTime? uploadedAt,
  }) = _VehiclePhoto;

  factory VehiclePhoto.fromJson(Map<String, dynamic> json) =>
      _$VehiclePhotoFromJson(json);
}

/// Data for creating a new vehicle
@freezed
abstract class VehicleCreate with _$VehicleCreate {
  const factory VehicleCreate({
    required String name,
    @JsonKey(name: 'plate_number') required String plateNumber,
    @Default(4) int capacity,
    int? year,
    String? model,
    String? color,
    @JsonKey(name: 'image_url') String? imageUrl,
    String? description,
  }) = _VehicleCreate;

  factory VehicleCreate.fromJson(Map<String, dynamic> json) =>
      _$VehicleCreateFromJson(json);
}

/// Data for updating a vehicle
@freezed
abstract class VehicleUpdate with _$VehicleUpdate {
  const factory VehicleUpdate({
    String? name,
    @JsonKey(name: 'plate_number') String? plateNumber,
    int? capacity,
    int? year,
    String? model,
    String? color,
    @JsonKey(name: 'image_url') String? imageUrl,
    String? description,
    @JsonKey(name: 'is_active') bool? isActive,
  }) = _VehicleUpdate;

  factory VehicleUpdate.fromJson(Map<String, dynamic> json) =>
      _$VehicleUpdateFromJson(json);
}
