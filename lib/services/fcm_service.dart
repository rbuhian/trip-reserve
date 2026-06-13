import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/router.dart';

/// Top-level handler for background FCM messages (must be a top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background message: ${message.messageId}');
}

/// Service for managing FCM push notifications
class FCMService {
  FCMService._();
  static final FCMService instance = FCMService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const _androidChannel = AndroidNotificationChannel(
    'trip_reserve_channel',
    'Trip Reserve Notifications',
    description: 'Booking and trip update notifications',
    importance: Importance.high,
  );

  bool _initialized = false;

  /// Initialize FCM — call once after Firebase.initializeApp() succeeds
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Set up local notifications for foreground messages
    await _initLocalNotifications();

    // Request permission
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('FCM permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      // Get token and save to Supabase
      await saveToken();

      // Listen for token refreshes
      _messaging.onTokenRefresh.listen(_onTokenRefresh);
    }

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    // Handle the tap that cold-started the app from a terminated state
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationData(
        initialMessage.data,
        fallbackTitle: initialMessage.notification?.title,
      );
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // Create high-importance channel on Android
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_androidChannel);
  }

  Future<void> saveToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      await _upsertToken(token);
    } catch (e) {
      debugPrint('FCM: failed to save token: $e');
    }
  }

  Future<void> _onTokenRefresh(String token) async {
    debugPrint('FCM token refreshed');
    await _upsertToken(token);
  }

  Future<void> _upsertToken(String token) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await Supabase.instance.client.from('device_tokens').upsert(
        {
          'user_id': userId,
          'token': token,
          'platform': defaultTargetPlatform == TargetPlatform.iOS
              ? 'ios'
              : 'android',
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id, token',
      );
      debugPrint('FCM token saved for user $userId');
    } catch (e) {
      debugPrint('FCM: failed to upsert token: $e');
    }
  }

  /// Delete this device's token from Supabase (call on logout)
  Future<void> deleteToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      await Supabase.instance.client
          .from('device_tokens')
          .delete()
          .eq('user_id', userId)
          .eq('token', token);

      await _messaging.deleteToken();
      debugPrint('FCM token deleted');
    } catch (e) {
      debugPrint('FCM: failed to delete token: $e');
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    debugPrint('FCM foreground message: ${message.notification?.title}');
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      // Carry the FCM data so a tap on the foreground notification can deep-link.
      payload: jsonEncode(message.data),
    );
  }

  /// Tap on a notification while the app is backgrounded.
  void _onMessageOpenedApp(RemoteMessage message) {
    debugPrint('FCM notification tapped: ${message.data}');
    _handleNotificationData(
      message.data,
      fallbackTitle: message.notification?.title,
    );
  }

  /// Tap on a local notification shown while the app was in the foreground.
  void _onLocalNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final data = (jsonDecode(payload) as Map).cast<String, dynamic>();
      _handleNotificationData(data);
    } catch (e) {
      debugPrint('FCM: failed to parse notification payload: $e');
    }
  }

  /// Route a notification tap based on its `type` data field.
  void _handleNotificationData(
    Map<String, dynamic> data, {
    String? fallbackTitle,
  }) {
    final type = data['type']?.toString();
    final bookingId = data['booking_id']?.toString();
    if (bookingId == null || bookingId.isEmpty) return;

    switch (type) {
      case 'new_message':
        unawaited(_navigateToChat(bookingId, fallbackTitle));
        break;
      // Other notification types (driver_assigned, trip_started, …) could
      // deep-link to the booking details screen here in the future.
      default:
        break;
    }
  }

  /// Open the chat for [bookingId], choosing the customer or driver route from
  /// the signed-in user's role. Retries briefly while the navigator spins up
  /// (e.g. a cold start from a terminated state).
  Future<void> _navigateToChat(
    String bookingId,
    String? title, {
    int attempt = 0,
  }) async {
    final context = rootNavigatorKey.currentContext;
    if (context == null) {
      if (attempt >= 10) return; // give up after ~5s
      await Future.delayed(const Duration(milliseconds: 500));
      return _navigateToChat(bookingId, title, attempt: attempt + 1);
    }

    final role = Supabase
        .instance.client.auth.currentUser?.userMetadata?['role'] as String?;
    final path = role == 'driver'
        ? '/driver/bookings/$bookingId/chat'
        : '/bookings/$bookingId/chat';

    unawaited(context.push(path, extra: title));
  }
}
