import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:fixilya_app/core/config/app_config.dart';
import 'package:fixilya_app/core/utils/api_error_handler.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  late final Dio authDio;
  late final Dio userDio;
  late final Dio bookingDio;
  late final Dio notificationDio;
  late final Dio callDio;
  late final CacheOptions _cacheOptions;

  // Service URLs — loaded from --dart-define or AppConfig defaults
  static String get _authServiceUrl => AppConfig.authServiceUrl;
  static String get _userServiceUrl => AppConfig.userServiceUrl;
  static String get _bookingServiceUrl => AppConfig.bookingServiceUrl;
  static String get _notificationServiceUrl => AppConfig.notificationServiceUrl;
  static String get _callServiceUrl => AppConfig.callServiceUrl;

  void init() {
    if (kDebugMode) {
      debugPrint(
        'API Client → auth: $_authServiceUrl | user: $_userServiceUrl | platform: ${Platform.operatingSystem}',
      );
    }

    // In-memory cache for the current session.
    //
    // Policy: CachePolicy.request — always tries the network first,
    // then falls back to a stale cached response on network errors
    // (except 401/403 which require re-authentication).
    //
    // maxStale is set to 7 days so that a cached GET response can be
    // served offline for up to a week after the last successful fetch.
    // The primary offline cache lives in DataPersistenceService at the
    // domain/service layer; this Dio-level cache is a secondary safety
    // net for any API call that does not yet have explicit service-layer
    // caching.
    _cacheOptions = CacheOptions(
      store: MemCacheStore(),
      policy: CachePolicy.request,
      hitCacheOnErrorExcept: [401, 403],
      maxStale: const Duration(days: 7),
      priority: CachePriority.normal,
    );

    // Auth Service Dio
    authDio = _createDio(_authServiceUrl);

    // User Service Dio
    userDio = _createDio(_userServiceUrl);

    // Booking Service Dio
    bookingDio = _createDio(_bookingServiceUrl);

    // Notification Service Dio
    notificationDio = _createDio(_notificationServiceUrl);

    // Call Service Dio
    callDio = _createDio(_callServiceUrl);
  }

  Dio _createDio(String baseUrl) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Cache interceptor must be first: short-circuits on cache hits
    // before the auth interceptor fetches a Firebase token.
    // Only caches GET requests by default; POST/PUT/DELETE are bypassed.
    dio.interceptors.add(DioCacheInterceptor(options: _cacheOptions));

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              final token = await user.getIdToken();
              if (token != null && token.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $token';
                // Never log tokens — even partial ones
              }
            }
          } catch (e) {
            if (kDebugMode) debugPrint('ApiClient: token injection error: $e');
          }
          if (kDebugMode) {
            debugPrint('→ ${options.method} ${options.baseUrl}${options.path}');
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            debugPrint(
              '← ${response.statusCode} ${response.requestOptions.path}',
            );
          }
          return handler.next(response);
        },
        onError: (DioException error, handler) async {
          if (kDebugMode) {
            debugPrint(
              'ApiClient error [${error.response?.statusCode}] ${error.type}: ${error.requestOptions.path}',
            );
          }

          // Auto-retry on 401 with a fresh Firebase ID token
          if (error.response?.statusCode == 401) {
            try {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                await user.reload();
                final freshToken = await FirebaseAuth.instance.currentUser
                    ?.getIdToken(true);
                if (freshToken != null && freshToken.isNotEmpty) {
                  final opts = error.requestOptions;
                  opts.headers['Authorization'] = 'Bearer $freshToken';
                  final retryResponse = await dio.fetch(opts);
                  return handler.resolve(retryResponse);
                }
              }
            } catch (e) {
              if (kDebugMode) debugPrint('ApiClient: 401 retry failed: $e');
            }
          }

          return handler.next(error);
        },
      ),
    );

    return dio;
  }

  // ✅ Backward compatibility
  Dio get dio => authDio;
}
