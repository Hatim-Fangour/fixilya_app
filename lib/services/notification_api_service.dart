import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:fixilya_app/services/api_client.dart';

/// Frontend service that talks to the notification microservice (port 3005).
class NotificationApiService {
  final _dio = ApiClient().notificationDio;

  /// Fetches the unread notification count from the backend.
  Future<int> getUnreadCount() async {
    try {
      final response = await _dio.get('/api/notifications/unread-count');
      final data = response.data;
      if (data is Map && data['success'] == true) {
        return (data['count'] as num?)?.toInt() ?? 0;
      }
      return 0;
    } catch (e) {
      if (kDebugMode) debugPrint('NotificationApiService.getUnreadCount: $e');
      return 0;
    }
  }

  /// Returns a stream that polls the unread count every [interval].
  Stream<int> streamUnreadCount({
    Duration interval = const Duration(seconds: 15),
  }) async* {
    yield await getUnreadCount();
    yield* Stream.periodic(interval).asyncMap((_) => getUnreadCount());
  }

  /// Fetches notifications list from the backend.
  Future<List<Map<String, dynamic>>> getNotifications({
    int limit = 20,
    bool unreadOnly = false,
  }) async {
    try {
      final response = await _dio.get(
        '/api/notifications',
        queryParameters: {
          'limit': limit,
          if (unreadOnly) 'unreadOnly': 'true',
        },
      );
      final data = response.data;
      if (data is Map && data['success'] == true && data['data'] is List) {
        return (data['data'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) debugPrint('NotificationApiService.getNotifications: $e');
      return [];
    }
  }

  /// Marks a single notification as read.
  Future<bool> markAsRead(String notificationId) async {
    try {
      final response = await _dio.put('/api/notifications/$notificationId/read');
      return response.data?['success'] == true;
    } catch (e) {
      if (kDebugMode) debugPrint('NotificationApiService.markAsRead: $e');
      return false;
    }
  }

  /// Marks all notifications as read.
  Future<bool> markAllAsRead() async {
    try {
      final response = await _dio.put('/api/notifications/read-all');
      return response.data?['success'] == true;
    } catch (e) {
      if (kDebugMode) debugPrint('NotificationApiService.markAllAsRead: $e');
      return false;
    }
  }
}
