import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/enums.dart';

/// Authentication service using Supabase Auth
class AuthService {
  final SupabaseClient _client;

  AuthService(this._client);

  /// Get current authenticated user
  User? get currentUser => _client.auth.currentUser;

  /// Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  /// Stream of auth state changes
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Sign up with email and password
  ///
  /// Creates a new user account and profile
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    UserRole role = UserRole.customer,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'phone': phone,
          'role': role.value,
        },
      );

      if (response.user == null) {
        throw AuthServiceException('Failed to create account');
      }

      return response;
    } on AuthException catch (e) {
      throw AuthServiceException.fromAuthException(e);
    }
  }

  /// Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw AuthServiceException('Invalid email or password');
      }

      return response;
    } on AuthException catch (e) {
      throw AuthServiceException.fromAuthException(e);
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (e) {
      throw AuthServiceException.fromAuthException(e);
    }
  }

  /// Send password reset email
  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      throw AuthServiceException.fromAuthException(e);
    }
  }

  /// Update password for current user
  Future<void> updatePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } on AuthException catch (e) {
      throw AuthServiceException.fromAuthException(e);
    }
  }

  /// Update user metadata
  Future<void> updateUserMetadata(Map<String, dynamic> data) async {
    try {
      await _client.auth.updateUser(
        UserAttributes(data: data),
      );
    } on AuthException catch (e) {
      throw AuthServiceException.fromAuthException(e);
    }
  }

  /// Get user role from metadata
  UserRole? getUserRole() {
    final metadata = currentUser?.userMetadata;
    if (metadata == null) return null;

    final roleStr = metadata['role'] as String?;
    if (roleStr == null) return UserRole.customer;

    return UserRole.fromString(roleStr);
  }

  /// Get user's full name from metadata
  String? getUserFullName() {
    return currentUser?.userMetadata?['full_name'] as String?;
  }

  /// Refresh the current session
  Future<AuthResponse> refreshSession() async {
    try {
      final response = await _client.auth.refreshSession();
      return response;
    } on AuthException catch (e) {
      throw AuthServiceException.fromAuthException(e);
    }
  }
}

/// Custom exception for auth errors
class AuthServiceException implements Exception {
  final String message;
  final String? code;

  AuthServiceException(this.message, {this.code});

  factory AuthServiceException.fromAuthException(AuthException e) {
    return AuthServiceException(
      _mapErrorMessage(e.message),
      code: e.statusCode,
    );
  }

  static String _mapErrorMessage(String message) {
    // Map Supabase error messages to user-friendly messages
    final lowerMessage = message.toLowerCase();

    if (lowerMessage.contains('invalid login credentials')) {
      return 'Invalid email or password';
    }
    if (lowerMessage.contains('email not confirmed')) {
      return 'Please verify your email address';
    }
    if (lowerMessage.contains('user already registered')) {
      return 'An account with this email already exists';
    }
    if (lowerMessage.contains('password')) {
      return 'Password must be at least 6 characters';
    }
    if (lowerMessage.contains('email')) {
      return 'Please enter a valid email address';
    }
    if (lowerMessage.contains('network')) {
      return 'Network error. Please check your connection';
    }

    return message;
  }

  @override
  String toString() => message;
}
