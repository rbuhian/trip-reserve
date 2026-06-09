import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Application configuration
///
/// IMPORTANT: Do not hardcode sensitive values here.
/// Use environment variables or secure storage for production.
class AppConfig {
  AppConfig._();

  // Supabase Configuration - loaded from .env file
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';

  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  // Google Maps API Key
  static String get googleMapsApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  // App Settings
  static const String appName = 'Trip Reserve';
  static const String appVersion = '1.0.0';

  // Booking Settings
  static const int maxBookingDaysAhead = 30;
  static const int cancellationDeadlineHours = 24;

  // Currency
  static const String currencyCode = 'PHP';
  static const String currencySymbol = '₱';

  // Email Configuration
  static const String emailFromAddress = 'bookings@tripreserve.ph';
  static const String emailFromName = 'Trip Reserve';

  // Brand Colors (for email templates)
  static const String brandNavyColor = '#0C2340';
  static const String brandAmberColor = '#F5A623';
}
