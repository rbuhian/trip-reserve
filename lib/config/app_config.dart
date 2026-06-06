/// Application configuration
///
/// IMPORTANT: Do not hardcode sensitive values here.
/// Use environment variables or secure storage for production.
class AppConfig {
  AppConfig._();

  // Supabase Configuration
  // Replace with actual values from .env in production
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  // Google Maps API Key
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  // App Settings
  static const String appName = 'Trip Reserve';
  static const String appVersion = '1.0.0';

  // Booking Settings
  static const int maxBookingDaysAhead = 30;
  static const int cancellationDeadlineHours = 24;

  // Currency
  static const String currencyCode = 'PHP';
  static const String currencySymbol = '₱';
}
