import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';

import 'package:fixilya_app/core/utils/api_error_handler.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  late final Dio authDio;
  late final Dio userDio;

  // ✅ Service URLs
  static String get _authServiceUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3001/api';
    } else if (Platform.isIOS) {
      return 'http://localhost:3001/api';
    } else {
      return 'http://localhost:3001/api';
    }
  }

  static String get _userServiceUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3002/api';
    } else if (Platform.isIOS) {
      return 'http://localhost:3002/api';
    } else {
      return 'http://localhost:3002/api';
    }
  }

  void init() {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🌐 API Client Initialized');
    print('📍 Auth Service: $_authServiceUrl');
    print('📍 User Service: $_userServiceUrl');
    print('📱 Platform: ${Platform.operatingSystem}');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // Auth Service Dio
    authDio = _createDio(_authServiceUrl);

    // User Service Dio
    userDio = _createDio(_userServiceUrl);
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

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              // ✅ Get token with force refresh if needed
              final token = await user.getIdToken();
              if (token != null && token.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $token';
                print('✅ Token added to request: ${token.substring(0, 20)}...');
              } else {
                print('⚠️ Warning: No token available for request');
              }
            } else {
              print('⚠️ Warning: No user logged in for request');
            }
          } catch (e) {
            print('❌ Error getting token: $e');
          }

          print(
            '🌐 REQUEST[${options.method}] => ${options.baseUrl}${options.path}',
          );
          if (options.data != null) {
            print('📦 Data: ${options.data}');
          }

          return handler.next(options);
        },
        onResponse: (response, handler) {
          print('✅ RESPONSE[${response.statusCode}] => ${response.data}');
          return handler.next(response);
        },
        onError: (DioException error, handler) async {
          print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          print('❌ API ERROR');
          print('Type: ${error.type}');
          print('Status Code: ${error.response?.statusCode}');
          print('Message: ${error.message}');
          print('Response Data: ${error.response?.data}');
          print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

          // ✅ CRITICAL: Retry with fresh token on 401
          // if (error.response?.statusCode == 401) {
          //   print('🔄 Got 401, attempting token refresh and retry...');

          //   try {
          //     final user = FirebaseAuth.instance.currentUser;
          //     if (user != null) {
          //       // Force reload user and get fresh token
          //       await user.reload();
          //       final freshToken = await FirebaseAuth.instance.currentUser
          //           ?.getIdToken(true);

          //       if (freshToken != null && freshToken.isNotEmpty) {
          //         print('✅ Got fresh token, retrying request...');

          //         // Clone the failed request with new token
          //         final options = error.requestOptions;
          //         options.headers['Authorization'] = 'Bearer $freshToken';

          //         try {
          //           // Retry the request
          //           final response = await dio.fetch(options);
          //           print('✅ Retry successful!');
          //           return handler.resolve(response);
          //         } catch (retryError) {
          //           print('❌ Retry failed: $retryError');
          //           // If retry fails, fall through to error handler
          //         }
          //       } else {
          //         print('⚠️ Could not get fresh token');
          //       }
          //     } else {
          //       print('⚠️ No user found for token refresh');
          //     }
          //   } catch (e) {
          //     print('❌ Token refresh error: $e');
          //   }
          // }

          // ✅ Use global error handler (will logout if retry failed)
          // await ApiErrorHandler.handleError(error);

          return handler.next(error);
        },
      ),
    );

    return dio;
  }

  // ✅ Backward compatibility
  Dio get dio => authDio;
}
