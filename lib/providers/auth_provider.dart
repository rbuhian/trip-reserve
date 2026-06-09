import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models/enums.dart';
import '../models/user.dart' as app;
import '../services/auth_service.dart';
import 'supabase_provider.dart';

/// Current authenticated user state
///
/// Returns null if not authenticated
final authUserProvider = StreamProvider<app.User?>((ref) {
  final client = ref.watch(supabaseClientProvider) as supabase.SupabaseClient;
  final authService = ref.watch(authServiceProvider);

  // Create a stream controller to emit user changes
  final controller = StreamController<app.User?>();

  // Get initial user
  final initialUser = _mapAuthUser(client.auth.currentUser, authService);
  controller.add(initialUser);

  // Listen to auth changes
  final subscription = client.auth.onAuthStateChange.listen((state) {
    final user = _mapAuthUser(state.session?.user, authService);
    controller.add(user);
  });

  // Cleanup
  ref.onDispose(() {
    subscription.cancel();
    controller.close();
  });

  return controller.stream;
});

/// Map Supabase auth user to app User model
app.User? _mapAuthUser(supabase.User? authUser, AuthService authService) {
  if (authUser == null) return null;

  final metadata = authUser.userMetadata ?? {};

  return app.User(
    id: authUser.id,
    email: authUser.email ?? '',
    fullName: metadata['full_name'] as String? ?? 'User',
    phone: metadata['phone'] as String?,
    role: UserRole.fromString(metadata['role'] as String? ?? 'customer'),
    avatarUrl: metadata['avatar_url'] as String?,
    createdAt: DateTime.tryParse(authUser.createdAt),
  );
}

/// Check if user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  final user = ref.watch(authUserProvider);
  return user.valueOrNull != null;
});

/// Get current user's role
final userRoleProvider = Provider<UserRole?>((ref) {
  final user = ref.watch(authUserProvider);
  return user.valueOrNull?.role;
});

/// Auth actions notifier for login/logout/register
final authActionsProvider =
    AsyncNotifierProvider<AuthActionsNotifier, void>(AuthActionsNotifier.new);

class AuthActionsNotifier extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {
    // Nothing to initialize
  }

  AuthService get _authService => ref.read(authServiceProvider);

  /// Sign in with email and password
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      await _authService.signIn(
        email: email,
        password: password,
      );
    });
  }

  /// Sign up with email and password
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    UserRole role = UserRole.customer,
  }) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      await _authService.signUp(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
        role: role,
      );
    });
  }

  /// Sign out
  Future<void> signOut() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      await _authService.signOut();
    });
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      await _authService.resetPassword(email);
    });
  }

  /// Update user profile
  Future<void> updateProfile({
    String? fullName,
    String? phone,
    String? avatarUrl,
  }) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final metadataUpdates = <String, dynamic>{};
      if (fullName != null) metadataUpdates['full_name'] = fullName;
      if (phone != null) metadataUpdates['phone'] = phone;
      if (avatarUrl != null) metadataUpdates['avatar_url'] = avatarUrl;

      if (metadataUpdates.isNotEmpty) {
        final client = ref.read(supabaseClientProvider) as supabase.SupabaseClient;
        final userId = client.auth.currentUser?.id;

        await Future.wait([
          _authService.updateUserMetadata(metadataUpdates),
          if (userId != null)
            client.from('users').update({
              if (fullName != null) 'full_name': fullName,
              if (phone != null) 'phone': phone,
              if (avatarUrl != null) 'avatar_url': avatarUrl,
            }).eq('id', userId),
        ]);

        await _authService.refreshSession();
      }
    });
  }
}

/// Loading state for auth actions
final authLoadingProvider = Provider<bool>((ref) {
  final authActions = ref.watch(authActionsProvider);
  return authActions.isLoading;
});

/// Error state for auth actions
final authErrorProvider = Provider<String?>((ref) {
  final authActions = ref.watch(authActionsProvider);
  return authActions.hasError ? authActions.error.toString() : null;
});
