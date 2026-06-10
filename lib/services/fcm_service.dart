import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      await _saveToken();

      // Listen for token refreshes
      _messaging.onTokenRefresh.listen(_onTokenRefresh);
    }

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);
  }

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotifications.initialize(initSettings);

    // Create high-importance channel on Android
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_androidChannel);
  }

  Future<void> _saveToken() async {
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
    );
  }

  void _onMessageOpenedApp(RemoteMessage message) {
    debugPrint('FCM notification tapped: ${message.data}');
    // Navigation based on message data can be added here (CUST-44/45/46)
  }
}
