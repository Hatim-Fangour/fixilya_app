// lib/services/notification_service.dart
//
// Full FCM push notification service for Fixilya.
//
// Responsibilities:
//  - Request permission on first launch
//  - Upload the FCM device token to the backend
//  - Display foreground notifications via flutter_local_notifications
//  - Handle background / terminated messages
//  - Route the user to the correct screen on notification tap
//  - Refresh token when Firebase rotates it

import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:fixilya_app/services/api_client.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Background handler — MUST be a top-level function (not a class method)
// ─────────────────────────────────────────────────────────────────────────────

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialised by the OS isolate at this point.
  if (kDebugMode) {
    debugPrint('[FCM-bg] ${message.notification?.title}');
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  final _api = ApiClient();

  // Android notification channel
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'fixilya_high_importance',
    'Fixilya Notifications',
    description: 'Booking updates, call alerts, and messages.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  // ─── Initialisation ───────────────────────────────────────────────────────

  /// Call once from main() after Firebase.initializeApp().
  Future<void> init() async {
    // Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Create Android high-importance channel
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // Initialise local notifications plugin
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _local.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onLocalTap,
    );

    // Request permission
    await _requestPermission();

    // iOS foreground presentation
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Upload token to backend & listen for refreshes
    await _uploadToken();
    _fcm.onTokenRefresh.listen(_uploadToken);

    // Foreground message handler
    FirebaseMessaging.onMessage.listen(_onForeground);

    // Tap when app was in background
    FirebaseMessaging.onMessageOpenedApp.listen(_onFcmTap);

    // Tap when app was terminated
    final initial = await _fcm.getInitialMessage();
    if (initial != null) _onFcmTap(initial);

    if (kDebugMode) debugPrint('[NotificationService] ready');
  }

  // ─── Permission ───────────────────────────────────────────────────────────

  Future<void> _requestPermission() async {
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );
  }

  // ─── Token management ─────────────────────────────────────────────────────

  Future<void> _uploadToken([String? token]) async {
    try {
      final t = token ?? await _fcm.getToken();
      if (t == null || t.isEmpty) return;
      await _api.dio.post('/notifications/register-token', data: {'fcmToken': t});
    } catch (e) {
      if (kDebugMode) debugPrint('[NotificationService] token upload failed: $e');
    }
  }

  /// Call on logout to stop notifications for this device.
  Future<void> removeToken() async {
    try {
      final token = await _fcm.getToken();
      if (token != null && token.isNotEmpty) {
        await _api.dio.delete('/notifications/remove-token', data: {'fcmToken': token});
      }
      await _fcm.deleteToken();
    } catch (e) {
      if (kDebugMode) debugPrint('[NotificationService] token removal failed: $e');
    }
  }

  // ─── Message handlers ─────────────────────────────────────────────────────

  /// Shows a local notification when a FCM message arrives in the foreground
  /// (FCM does NOT automatically show a banner while the app is open).
  /// Incoming call notifications use full-screen intent to appear over the lock screen.
  void _onForeground(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final isCall = (message.data['type'] as String?) == 'incoming_call';

    _local.show(
      message.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          fullScreenIntent: isCall,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _onFcmTap(RemoteMessage message) => _route(message.data);

  void _onLocalTap(NotificationResponse response) {
    if (response.payload == null || response.payload!.isEmpty) return;
    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      _route(data);
    } catch (_) {}
  }

  // ─── Deep-link routing ────────────────────────────────────────────────────

  /// Routes the user to the appropriate screen.
  ///
  /// Backend notification data keys:
  ///   type        – booking_request | booking_update | incoming_call |
  ///                 new_message | generic
  ///   bookingId   – for booking types
  ///   callId      – for incoming_call
  ///   chatId      – for new_message
  void _route(Map<String, dynamic> data) {
    final type = data['type'] as String? ?? 'generic';

    // Delay so the widget tree is fully built on cold start
    Future.delayed(const Duration(milliseconds: 400), () {
      switch (type) {
        case 'booking_request':
        case 'booking_update':
          final bookingId = data['bookingId'] as String?;
          if (bookingId != null) {
            Get.toNamed('/booking-details', arguments: {'bookingId': bookingId});
          }
        case 'incoming_call':
          final callId = data['callId'] as String?;
          if (callId != null) {
            Get.toNamed('/incoming-call', arguments: data);
          }
        case 'new_message':
          final chatId = data['chatId'] as String?;
          if (chatId != null) {
            Get.toNamed('/chat-room', arguments: data);
          }
        default:
          Get.toNamed('/widget-tree');
      }
    });
  }
}
