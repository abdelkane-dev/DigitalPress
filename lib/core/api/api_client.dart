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
class HealthCheckResult {
  final bool isOnline;
  final String? serverMessage;

  const HealthCheckResult({required this.isOnline, this.serverMessage});
}

String buildHealthStatusMessage({
  required bool isOnline,
  String? serverMessage,
}) {
  if (!isOnline) {
    return 'Le serveur est indisponible';
  }

  final message = (serverMessage ?? '').trim();
  if (message.isNotEmpty) {
    return message;
  }

  return 'Serveur disponible';
}

/// Intercepteur de retry avec backoff exponentiel — conçu pour les cold-starts de Render
/// (le serveur peut mettre jusqu'à 50 s à répondre après un redémarrage automatique).
class _RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;
  final Duration initialDelay;

  _RetryInterceptor({
    required this.dio,
    this.maxRetries = 3,
    this.initialDelay = const Duration(seconds: 2),
  });

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // On ne retente que les erreurs réseau (timeout, connexion refusée), pas les 4xx/5xx
    final isNetworkError = err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.sendTimeout;

    final attempt = (err.requestOptions.extra['_retry_count'] as int?) ?? 0;

    if (!isNetworkError || attempt >= maxRetries) {
      return handler.next(err);
    }

    // Backoff exponentiel : 2s, 4s, 8s
    final delay = initialDelay * (attempt + 1);
    await Future.delayed(delay);

    final options = err.requestOptions;
    options.extra['_retry_count'] = attempt + 1;

    try {
      final response = await dio.fetch(options);
      return handler.resolve(response);
    } on DioException catch (retryErr) {
      return handler.next(retryErr);
    }
  }
}

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

    // Retry pour les cold-starts Render (point 2 — problèmes de connexion)
    _dio.interceptors.add(_RetryInterceptor(dio: _dio));

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
  Future<HealthCheckResult> healthCheck() async {
    try {
      final res = await _dio.get(
        'health/',
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

      if (res.statusCode == 200) {
        final data = res.data;
        String? message;

        if (data is Map<String, dynamic>) {
          final service = data['service']?.toString();
          final status = data['status']?.toString();
          final version = data['version']?.toString();

          final parts = [service, status, version]
              .whereType<String>()
              .where((part) => part.trim().isNotEmpty)
              .toList();

          if (parts.isNotEmpty) {
            message = parts.join(' • ');
          }
        }

        return HealthCheckResult(isOnline: true, serverMessage: message);
      }

      return const HealthCheckResult(isOnline: false);
    } catch (_) {
      return const HealthCheckResult(isOnline: false);
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
