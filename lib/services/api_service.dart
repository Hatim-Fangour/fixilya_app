import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  late final Dio _dio;

  // ✅ Base URL Configuration
  static const String _baseUrl = 'http://localhost:3001/api';
  // For Android Emulator: 'http://10.0.2.2:3001/api'
  // For iOS Simulator: 'http://localhost:3001/api'
  // For Real Device: 'http://YOUR_LOCAL_IP:3001/api' (e.g., 'http://192.168.1.100:3001/api')

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

          print('🌐 REQUEST[${options.method}] => ${options.path}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          print('✅ RESPONSE[${response.statusCode}] => ${response.data}');
          return handler.next(response);
        },
        onError: (DioException e, handler) {
          print('❌ ERROR[${e.response?.statusCode}] => ${e.message}');
          
          // ✅ Handle common errors
          if (e.type == DioExceptionType.connectionTimeout) {
            print('⏱️ Connection timeout');
          } else if (e.type == DioExceptionType.receiveTimeout) {
            print('⏱️ Receive timeout');
          } else if (e.response?.statusCode == 401) {
            print('🔐 Unauthorized - token expired');
          }
          
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