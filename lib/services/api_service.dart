import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:fixilya_app/core/config/app_config.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  late final Dio _dio;

  static String get _baseUrl => AppConfig.authServiceUrl;

  void init() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // ✅ Add request interceptor (like Axios interceptors)
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // ✅ Automatically add auth token to every request
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            final token = await user.getIdToken();
            options.headers['Authorization'] = 'Bearer $token';
          }

          if (kDebugMode) debugPrint('REQUEST[${options.method}] => ${options.path}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) debugPrint('RESPONSE[${response.statusCode}] => ${response.requestOptions.path}');
          return handler.next(response);
        },
        onError: (DioException e, handler) {
          if (kDebugMode) debugPrint('ERROR[${e.response?.statusCode}] => ${e.message}');
          
          return handler.next(e);
        },
      ),
    );
  }

  Dio get dio => _dio;

  // ✅ Convenience methods (like Axios)
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) {
    return _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data}) {
    return _dio.post(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) {
    return _dio.put(path, data: data);
  }

  Future<Response> delete(String path) {
    return _dio.delete(path);
  }

  Future<Response> patch(String path, {dynamic data}) {
    return _dio.patch(path, data: data);
  }
}