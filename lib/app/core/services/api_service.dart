import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_constants.dart';

/// Dio singleton configurado com base URL e Firebase token no header.
/// Fallback automático: se Firebase não estiver disponível, omite o header.
class ApiService {
  late final Dio _dio;

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        headers: {'Content-Type': ApiConstants.contentType},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Inject Firebase ID token when available
          try {
            final user = FirebaseAuth.instance.currentUser;
            debugPrint('[ApiService] Current user: ${user?.uid}');
            if (user != null) {
              final token = await user.getIdToken();
              debugPrint('[ApiService] Token length: ${token?.length ?? 0}');
              if (token != null) {
                options.headers[ApiConstants.authorizationHeader] =
                    '${ApiConstants.bearerPrefix} $token';
              }
            } else {
              debugPrint('[ApiService] No current user, skipping token');
            }
          } catch (e) {
            debugPrint('[ApiService] Could not get Firebase token: $e');
          }
          handler.next(options);
        },
        onError: (error, handler) {
          debugPrint('[ApiService] Error: ${error.message}');
          handler.next(error);
        },
      ),
    );
  }

  Dio get dio => _dio;

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    return _dio.post(path, data: data, queryParameters: queryParameters);
  }

  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    return _dio.put(path, data: data, queryParameters: queryParameters);
  }

  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    return _dio.delete(path, data: data, queryParameters: queryParameters);
  }
}

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});
