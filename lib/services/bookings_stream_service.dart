import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fixilya_app/core/config/app_config.dart';

/// Backend SSE stream service — uses Dio with [ResponseType.stream].
///
/// Replaces the old [BookingsRealtimeService] (direct Firestore listeners).
/// Every method returns a Dart [Stream] that:
///   - opens an SSE connection to the booking-service
///   - emits the latest list / value on each Firestore snapshot pushed by server
///   - auto-reconnects on any error, 401 (token refresh), or server close
///   - cleans up the Dio request when the subscriber cancels
class BookingsStreamService {
  /// Base URL of the booking-service.
  /// Change to your real host for production.
  static String get _base => AppConfig.bookingServiceUrl;

  // ─────────────────────────────────────────────
  // PROVIDER STREAMS
  // ─────────────────────────────────────────────

  /// Pending booking requests for the current provider.
  Stream<List<Map<String, dynamic>>> streamBookingRequests() =>
      _listStream('/api/bookings/stream/requests');

  /// Confirmed + in-progress bookings for the current provider.
  Stream<List<Map<String, dynamic>>> streamActiveBookings() =>
      _listStream('/api/bookings/stream/active');

  /// Last 20 declined bookings for the provider.
  Stream<List<Map<String, dynamic>>> streamDeclinedBookings() =>
      _listStream('/api/bookings/stream/declined');

  /// Last 20 activity feed items for the current user.
  Stream<List<Map<String, dynamic>>> streamRecentActivity() =>
      _listStream('/api/bookings/stream/activity');

  // ─────────────────────────────────────────────
  // CLIENT STREAMS
  // ─────────────────────────────────────────────

  /// Bookings for the current client. Pass [status] to filter.
  Stream<List<Map<String, dynamic>>> streamClientBookings({String? status}) {
    final path = status != null
        ? '/api/bookings/stream/client?status=$status'
        : '/api/bookings/stream/client';
    return _listStream(path);
  }

  // ─────────────────────────────────────────────
  // NOTIFICATION STREAMS
  // ─────────────────────────────────────────────

  /// Last 50 notifications for the current user.
  Stream<List<Map<String, dynamic>>> streamNotifications() =>
      _listStream('/api/bookings/stream/notifications');

  /// Live unread notification count as a plain integer.
  Stream<int> streamUnreadNotificationsCount() {
    return _rawStream('/api/bookings/stream/unread-count').map((data) {
      if (data is Map) return (data['count'] as num?)?.toInt() ?? 0;
      return 0;
    });
  }

  /// Live snapshot of a single booking document.
  /// Returns null when the booking does not exist.
  Stream<Map<String, dynamic>?> streamSingleBooking(String bookingId) {
    return _rawStream('/api/bookings/stream/booking/$bookingId').map((data) {
      if (data == null) return null;
      return _parseTimestamps(Map<String, dynamic>.from(data as Map));
    });
  }

  // ─────────────────────────────────────────────
  // INTERNAL — typed list wrapper
  // ─────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> _listStream(String path) {
    return _rawStream(path).map((data) {
      if (data is! List) return <Map<String, dynamic>>[];
      return data
          .whereType<Map>()
          .map((e) => _parseTimestamps(Map<String, dynamic>.from(e)))
          .toList();
    });
  }

  // ─────────────────────────────────────────────
  // INTERNAL — core SSE reader using Dio
  // ─────────────────────────────────────────────

  /// Opens a streaming GET to [path] and yields each `event:update`
  /// payload as decoded JSON.
  ///
  /// Reconnect policy:
  ///   - 401           → force-refresh Firebase token, retry after 1 s
  ///   - DioException  → retry after 3 s
  ///   - stream ends   → reconnect immediately (server closed connection)
  ///   - CancelToken   → subscriber unsubscribed, stop completely
  Stream<dynamic> _rawStream(String path) async* {
    // Emit an empty list immediately so the UI exits ConnectionState.waiting
    // right away, even before the first successful SSE connection.
    yield <dynamic>[];

    while (true) {
      final cancelToken = CancelToken();

      try {
        final token = await FirebaseAuth.instance.currentUser?.getIdToken(
          false,
        ); // non-force; force only on 401

        if (token == null) {
          await Future<void>.delayed(const Duration(seconds: 3));
          continue;
        }

        final dio = Dio(
          BaseOptions(
            baseUrl: _base,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: Duration.zero, // SSE stays open — no timeout
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'text/event-stream',
              'Cache-Control': 'no-cache',
            },
            responseType: ResponseType.stream, // stream body, don't buffer
          ),
        );

        final response = await dio.get<ResponseBody>(
          path,
          cancelToken: cancelToken,
        );

        if (response.statusCode == 401) {
          await FirebaseAuth.instance.currentUser?.getIdToken(true);
          await Future<void>.delayed(const Duration(seconds: 1));
          continue;
        }

        // ── SSE frame parser ─────────────────────
        String buffer = '';

        await for (final chunk
            in response.data!.stream.cast<List<int>>().transform(
              utf8.decoder,
            )) {
          buffer += chunk;

          // Events are separated by double newlines (\n\n)
          final events = buffer.split('\n\n');
          buffer = events.removeLast(); // keep incomplete trailing data

          for (final event in events) {
            if (event.trim().isEmpty) continue;

            String? eventType;
            String? dataLine;

            for (final line in event.split('\n')) {
              if (line.startsWith('event: ')) {
                eventType = line.substring(7).trim();
              } else if (line.startsWith('data: ')) {
                dataLine = line.substring(6).trim();
              }
              // ':' lines are heartbeats — ignore
            }

            if (eventType == 'update' && dataLine != null) {
              try {
                yield jsonDecode(dataLine);
              } catch (_) {
                // Malformed JSON — skip
              }
            }
          }
        }

        // Server closed the connection — reconnect immediately
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) {
          return; // Subscriber cancelled — stop the loop
        }
        await Future<void>.delayed(const Duration(seconds: 3));
      } catch (_) {
        await Future<void>.delayed(const Duration(seconds: 3));
      } finally {
        if (!cancelToken.isCancelled) cancelToken.cancel();
      }
    }
  }

  // ─────────────────────────────────────────────
  // INTERNAL — timestamp parsing
  // ─────────────────────────────────────────────

  static const _tsFields = [
    'createdAt',
    'updatedAt',
    'scheduledAt',
    'acceptedAt',
    'declinedAt',
    'startedAt',
    'completedAt',
    'cancelledAt',
    'readAt',
  ];

  /// Converts ISO-8601 strings in [data] to [DateTime] objects in-place.
  Map<String, dynamic> _parseTimestamps(Map<String, dynamic> data) {
    for (final field in _tsFields) {
      final v = data[field];
      if (v is String) data[field] = DateTime.tryParse(v);
    }
    return data;
  }
}
