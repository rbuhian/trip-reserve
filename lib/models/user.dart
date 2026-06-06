import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'user.freezed.dart';
part 'user.g.dart';

/// User profile model
@freezed
abstract class User with _$User {
  const factory User({
    required String id,
    required String email,
    @JsonKey(name: 'full_name') required String fullName,
    String? phone,
    @Default(UserRole.customer) UserRole role,
    @JsonKey(name: 'avatar_url') String? avatarUrl,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _User;

  const User._();

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  /// Check if user is a customer
  bool get isCustomer => role == UserRole.customer;

  /// Check if user is a driver
  bool get isDriver => role == UserRole.driver;

  /// Check if user is an admin
  bool get isAdmin => role == UserRole.admin;

  /// Get initials for avatar placeholder
  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
  }

  /// Get first name
  String get firstName {
    final parts = fullName.trim().split(' ');
    return parts.isNotEmpty ? parts.first : fullName;
  }
}

/// Lightweight user reference for embedding in other models
@freezed
abstract class UserRef with _$UserRef {
  const factory UserRef({
    required String id,
    @JsonKey(name: 'full_name') required String fullName,
    String? phone,
    @JsonKey(name: 'avatar_url') String? avatarUrl,
  }) = _UserRef;

  factory UserRef.fromJson(Map<String, dynamic> json) => _$UserRefFromJson(json);
}

/// Data for creating a new user (registration)
@freezed
abstract class UserCreate with _$UserCreate {
  const factory UserCreate({
    required String email,
    required String password,
    @JsonKey(name: 'full_name') required String fullName,
    String? phone,
    @Default(UserRole.customer) UserRole role,
  }) = _UserCreate;

  factory UserCreate.fromJson(Map<String, dynamic> json) =>
      _$UserCreateFromJson(json);
}

/// Data for updating a user profile
@freezed
abstract class UserUpdate with _$UserUpdate {
  const factory UserUpdate({
    @JsonKey(name: 'full_name') String? fullName,
    String? phone,
    @JsonKey(name: 'avatar_url') String? avatarUrl,
  }) = _UserUpdate;

  factory UserUpdate.fromJson(Map<String, dynamic> json) =>
      _$UserUpdateFromJson(json);
}
