import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';
import '../models/enums.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/otp_verification_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/customer/home_screen.dart';
import '../screens/customer/map_test_screen.dart';
import '../screens/customer/booking/booking_location_screen.dart';
import '../screens/customer/booking/booking_datetime_screen.dart';
import '../screens/customer/booking/booking_vehicle_screen.dart';
import '../screens/customer/booking/booking_addons_screen.dart';
import '../screens/customer/booking/booking_confirmation_screen.dart';
import '../screens/customer/booking/booking_success_screen.dart';
import '../screens/customer/bookings/customer_bookings_screen.dart';
import '../screens/customer/bookings/booking_details_screen.dart';
import '../screens/driver/driver_shell.dart';
import '../screens/driver/dashboard_screen.dart';
import '../screens/driver/vehicles/vehicle_list_screen.dart';
import '../screens/driver/vehicles/add_vehicle_screen.dart';
import '../screens/driver/vehicles/edit_vehicle_screen.dart';
import '../screens/driver/calendar/calendar_screen.dart';
import '../screens/driver/bookings/bookings_list_screen.dart';
import '../screens/driver/bookings/booking_details_screen.dart';
import '../screens/driver/profile/driver_profile_screen.dart';
import '../screens/admin/admin_shell.dart';
import '../screens/admin/dashboard_screen.dart';
import '../screens/admin/bookings/admin_bookings_screen.dart';
import '../screens/admin/bookings/admin_booking_details_screen.dart';
import '../screens/admin/users/admin_users_screen.dart';
import '../screens/admin/users/user_details_screen.dart';
import '../screens/admin/settings/admin_settings_screen.dart';
import '../screens/admin/reports/admin_reports_screen.dart';
import '../screens/admin/pricing/admin_pricing_screen.dart';
import '../screens/shared/chat/chat_screen.dart';

/// Root navigator key — lets non-widget code (e.g. FCM notification taps in
/// [FCMService]) navigate by pushing onto the active router.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Router provider with auth-aware redirects
final routerProvider = Provider<GoRouter>((ref) {
  final authUser = ref.watch(authUserProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoading = authUser.isLoading;
      final user = authUser.valueOrNull;
      final isAuthenticated = user != null;

      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/verify-otp' ||
          state.matchedLocation == '/forgot-password';

      // Still loading auth state
      if (isLoading) return null;

      // Not authenticated, redirect to login
      if (!isAuthenticated && !isAuthRoute) {
        return '/login';
      }

      // Authenticated but on auth route, redirect to home
      if (isAuthenticated && isAuthRoute) {
        return _getHomeForRole(user.role);
      }

      return null;
    },
    routes: [
      // Auth routes
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/verify-otp',
        builder: (context, state) {
          final email = state.extra as String? ?? '';
          return OtpVerificationScreen(email: email);
        },
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // Customer routes
      GoRoute(
        path: '/',
        redirect: (context, state) {
          final user = ref.read(authUserProvider).valueOrNull;
          if (user != null) {
            return _getHomeForRole(user.role);
          }
          return '/login';
        },
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/map-test',
        builder: (context, state) => const MapTestScreen(),
      ),
      GoRoute(
        path: '/book',
        builder: (context, state) => const BookingLocationScreen(),
      ),
      GoRoute(
        path: '/book/datetime',
        builder: (context, state) => const BookingDateTimeScreen(),
      ),
      GoRoute(
        path: '/book/vehicle',
        builder: (context, state) => const BookingVehicleScreen(),
      ),
      GoRoute(
        path: '/book/addons',
        builder: (context, state) => const BookingAddonsScreen(),
      ),
      GoRoute(
        path: '/book/confirm',
        builder: (context, state) => const BookingConfirmationScreen(),
      ),
      GoRoute(
        path: '/book/success/:ref',
        builder: (context, state) {
          final ref = state.pathParameters['ref']!;
          return BookingSuccessScreen(referenceNumber: ref);
        },
      ),

      // Customer bookings
      GoRoute(
        path: '/bookings',
        builder: (context, state) => const CustomerBookingsScreen(),
      ),
      GoRoute(
        path: '/bookings/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return BookingDetailsScreen(bookingId: id);
        },
      ),
      GoRoute(
        path: '/bookings/:id/chat',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ChatScreen(bookingId: id, title: state.extra as String?);
        },
      ),

      // TODO: Add more customer routes as screens are implemented
      // /profile - User profile

      // Driver routes with shell for bottom navigation
      ShellRoute(
        builder: (context, state, child) => DriverShell(child: child),
        routes: [
          GoRoute(
            path: '/driver',
            builder: (context, state) => const DriverDashboardScreen(),
          ),
          GoRoute(
            path: '/driver/vehicles',
            builder: (context, state) => const VehicleListScreen(),
          ),
          GoRoute(
            path: '/driver/calendar',
            builder: (context, state) => const CalendarScreen(),
          ),
          GoRoute(
            path: '/driver/bookings',
            builder: (context, state) => const DriverBookingsListScreen(),
          ),
          GoRoute(
            path: '/driver/profile',
            builder: (context, state) => const DriverProfileScreen(),
          ),
        ],
      ),

      // Driver routes without shell (full screen)
      GoRoute(
        path: '/driver/vehicles/add',
        builder: (context, state) => const AddVehicleScreen(),
      ),
      GoRoute(
        path: '/driver/vehicles/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return EditVehicleScreen(vehicleId: id);
        },
      ),
      GoRoute(
        path: '/driver/bookings/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return DriverBookingDetailsScreen(bookingId: id);
        },
      ),
      GoRoute(
        path: '/driver/bookings/:id/chat',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ChatScreen(bookingId: id, title: state.extra as String?);
        },
      ),

      // Admin routes with shell for bottom navigation
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: '/admin',
            builder: (context, state) => const AdminDashboardScreen(),
          ),
          GoRoute(
            path: '/admin/bookings',
            builder: (context, state) => const AdminBookingsScreen(),
          ),
          GoRoute(
            path: '/admin/users',
            builder: (context, state) => const AdminUsersScreen(),
          ),
          GoRoute(
            path: '/admin/settings',
            builder: (context, state) => const AdminSettingsScreen(),
          ),
        ],
      ),

      // Admin routes without shell (full screen)
      GoRoute(
        path: '/admin/bookings/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return AdminBookingDetailsScreen(bookingId: id);
        },
      ),
      GoRoute(
        path: '/admin/users/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return UserDetailsScreen(userId: id);
        },
      ),
      GoRoute(
        path: '/admin/reports',
        builder: (context, state) => const AdminReportsScreen(),
      ),
      GoRoute(
        path: '/admin/pricing',
        builder: (context, state) => const AdminPricingScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              state.matchedLocation,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMedium,
                  ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});

/// Get home route based on user role
String _getHomeForRole(UserRole role) {
  switch (role) {
    case UserRole.customer:
      return '/home';
    case UserRole.driver:
      return '/driver';
    case UserRole.admin:
      return '/admin';
  }
}

/// Legacy router for non-Riverpod contexts
/// Use routerProvider instead when possible
final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
  ],
);
