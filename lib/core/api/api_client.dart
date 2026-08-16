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
  // ─── PRODUCTION : plus aucun message d'état quand le serveur répond ──
  // L'ancien bannière « digital-press-api • ok • v1 » (message technique
  // renvoyé par /health/) s'affichait à chaque connexion — demandé : ne
  // rien afficher quand le serveur est disponible, garder uniquement le
  // message « Le serveur est indisponible » en cas de panne.
  if (isOnline) {
    return '';
  }

  return 'Le serveur est indisponible';
}

class ApiClient {
  late final Dio _dio;

  static String get baseUrl => ApiConfig.baseUrl;

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
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
        'Connexion impossible. Vérifiez votre réseau puis réessayez.',
      );
    }

    final path = e.requestOptions.path.toLowerCase();
    final isAuthEndpoint = path.contains('login') ||
        path.contains('register') ||
        path.contains('password') ||
        path.contains('verify') ||
        path.contains('token');

    final data = e.response?.data;
    String? serverMessage;
    Map<String, dynamic>? errorsMap;

    if (data is Map) {
      errorsMap = Map<String, dynamic>.from(data);
      if (data.containsKey('detail')) {
        final detail = data['detail'].toString();
        final lowerDetail = detail.toLowerCase();
        if (lowerDetail.contains('no active account found') ||
            lowerDetail.contains('invalid credentials') ||
            lowerDetail.contains('identifiants invalides') ||
            lowerDetail.contains('unable to log in')) {
          serverMessage = 'Adresse email ou mot de passe incorrect.';
        } else {
          serverMessage = detail;
        }
      } else if (data.containsKey('message')) {
        serverMessage = data['message'].toString();
      } else if (data.isNotEmpty) {
        final buffer = <String>[];
        data.forEach((key, value) {
          String valStr = '';
          if (value is List && value.isNotEmpty) {
            valStr = value.map((v) => v.toString()).join(', ');
          } else if (value != null) {
            valStr = value.toString();
          }

          if (valStr.isNotEmpty) {
            if (key == 'non_field_errors' || key == 'detail') {
              buffer.add(valStr);
            } else if (key == 'email') {
              buffer.add('Email : $valStr');
            } else if (key == 'password' || key == 'password2') {
              buffer.add('Mot de passe : $valStr');
            } else if (key == 'phone') {
              buffer.add('Téléphone : $valStr');
            } else if (key == 'username') {
              buffer.add('Nom d\'utilisateur : $valStr');
            } else if (key == 'company_name') {
              buffer.add('Nom d\'entreprise : $valStr');
            } else if (key == 'code') {
              buffer.add('Code : $valStr');
            } else {
              buffer.add('$key : $valStr');
            }
          }
        });

        if (buffer.isNotEmpty) {
          serverMessage = buffer.join('\n');
        }
      }
    }

    if (e.response?.statusCode == 401) {
      if (isAuthEndpoint || serverMessage != null) {
        return AuthFailure(serverMessage ?? 'Adresse email ou mot de passe incorrect.', errorsMap);
      }
      return AuthFailure('Session expirée. Veuillez vous reconnecter.', errorsMap);
    }

    if (serverMessage != null && serverMessage.isNotEmpty) {
      return ServerFailure(serverMessage, errorsMap);
    }

    return ServerFailure(
      'Une erreur est survenue (${e.response?.statusCode ?? "inconnue"})',
      errorsMap,
    );
  }

  void addInterceptor(Interceptor interceptor) {
    _dio.interceptors.add(interceptor);
  }
}
