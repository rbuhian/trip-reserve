import 'package:freezed_annotation/freezed_annotation.dart';

import 'user.dart';

part 'vehicle.freezed.dart';
part 'vehicle.g.dart';

/// Vehicle model
@freezed
class Vehicle with _$Vehicle {
  const factory Vehicle({
    required String id,
    @JsonKey(name: 'driver_id') required String driverId,
    required String name,
    @JsonKey(name: 'plate_number') required String plateNumber,
    @Default(4) int capacity,
    @JsonKey(name: 'image_url') String? imageUrl,
    String? description,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,

    // Joined data (optional)
    UserRef? driver,
  }) = _Vehicle;

  const Vehicle._();

  factory Vehicle.fromJson(Map<String, dynamic> json) => _$VehicleFromJson(json);

  /// Display text: "Toyota Innova • ABC 1234"
  String get displayText => '$name • $plateNumber';

  /// Capacity text: "4 passengers"
  String get capacityText =>
      '$capacity ${capacity == 1 ? 'passenger' : 'passengers'}';
}

/// Lightweight vehicle reference for lists
@freezed
class VehicleRef with _$VehicleRef {
  const factory VehicleRef({
    required String id,
    required String name,
    @JsonKey(name: 'plate_number') required String plateNumber,
    @Default(4) int capacity,
    @JsonKey(name: 'image_url') String? imageUrl,
  }) = _VehicleRef;

  factory VehicleRef.fromJson(Map<String, dynamic> json) =>
      _$VehicleRefFromJson(json);
}

/// Data for creating a new vehicle
@freezed
class VehicleCreate with _$VehicleCreate {
  const factory VehicleCreate({
    required String name,
    @JsonKey(name: 'plate_number') required String plateNumber,
    @Default(4) int capacity,
    @JsonKey(name: 'image_url') String? imageUrl,
    String? description,
  }) = _VehicleCreate;

  factory VehicleCreate.fromJson(Map<String, dynamic> json) =>
      _$VehicleCreateFromJson(json);
}

/// Data for updating a vehicle
@freezed
class VehicleUpdate with _$VehicleUpdate {
  const factory VehicleUpdate({
    String? name,
    @JsonKey(name: 'plate_number') String? plateNumber,
    int? capacity,
    @JsonKey(name: 'image_url') String? imageUrl,
    String? description,
    @JsonKey(name: 'is_active') bool? isActive,
  }) = _VehicleUpdate;

  factory VehicleUpdate.fromJson(Map<String, dynamic> json) =>
      _$VehicleUpdateFromJson(json);
}
