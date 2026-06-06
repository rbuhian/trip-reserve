import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';
import '../models/enums.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/customer/home_screen.dart';
import '../screens/customer/map_test_screen.dart';
import '../screens/customer/booking/booking_location_screen.dart';
import '../screens/driver/driver_shell.dart';
import '../screens/driver/dashboard_screen.dart';
import '../screens/driver/vehicles/vehicle_list_screen.dart';
import '../screens/driver/vehicles/add_vehicle_screen.dart';
import '../screens/driver/vehicles/edit_vehicle_screen.dart';
import '../screens/driver/calendar/calendar_screen.dart';
import '../screens/driver/bookings/bookings_list_screen.dart';

/// Router provider with auth-aware redirects
final routerProvider = Provider<GoRouter>((ref) {
  final authUser = ref.watch(authUserProvider);

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoading = authUser.isLoading;
      final user = authUser.valueOrNull;
      final isAuthenticated = user != null;

      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

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

      // TODO: Add more customer routes as screens are implemented
      // /book - Booking flow
      // /bookings - Booking history
      // /bookings/:id - Booking details
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

      // TODO: Admin routes (placeholder)
      // /admin - Admin dashboard
      // /admin/users - User management
      // /admin/bookings - All bookings
      // /admin/pricing - Pricing config
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
