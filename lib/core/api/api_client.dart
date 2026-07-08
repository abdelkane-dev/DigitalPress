import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/api_config.dart';
import '../exceptions/failures.dart';
import './auth_interceptor.dart';
import '../storage/secure_storage_service.dart';

/// Fournisseur Riverpod pour l'instance globale de [ApiClient].
final apiClientProvider = Provider<ApiClient>((ref) {
  final secureStorage = ref.watch(secureStorageServiceProvider);
  final refreshDio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
  final client = ApiClient();
  client.addInterceptor(AuthInterceptor(secureStorage, refreshDio));
  return client;
});

/// Client réseau basé sur [Dio] connecté au backend Django.
class ApiClient {
  late final Dio _dio;

  static String get baseUrl => ApiConfig.baseUrl;

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        contentType: 'application/json',
        headers: {'Accept': 'application/json'},
      ),
    );

    // Le corps des requêtes/réponses peut contenir des données sensibles
    // (mots de passe, tokens JWT, informations de paiement) : ce journal
    // détaillé ne doit exister qu'en développement, jamais en production.
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: true),
      );
    }
  }

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> patch(
    String path, {
    dynamic data,
    Options? options,
  }) async {
    try {
      return await _dio.patch(path, data: data, options: options);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> put(
    String path, {
    dynamic data,
    Options? options,
  }) async {
    try {
      return await _dio.put(path, data: data, options: options);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> delete(
    String path, {
    dynamic data,
    Options? options,
  }) async {
    try {
      return await _dio.delete(path, data: data, options: options);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Vérifie que le backend répond (sans authentification).
  Future<bool> healthCheck() async {
    try {
      final res = await _dio.get(
        'health/',
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Failure _handleError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return NetworkFailure(
        'Impossible de joindre le serveur (${ApiConfig.baseUrl}). '
        'Vérifiez que le backend Django est démarré.',
      );
    }
    if (e.response?.statusCode == 401) {
      return const AuthFailure('Session expirée');
    }
    final data = e.response?.data;
    String message = 'Une erreur est survenue';
    if (data is Map) {
      message = data['detail']?.toString() ??
          data['message']?.toString() ??
          data.values.first?.toString() ??
          message;
    }
    return ServerFailure(message);
  }

  void addInterceptor(Interceptor interceptor) {
    _dio.interceptors.add(interceptor);
  }
}
