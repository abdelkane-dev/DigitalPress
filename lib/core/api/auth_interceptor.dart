import 'package:dio/dio.dart';
import '../storage/secure_storage_service.dart';

/// Intercepteur moderne chargé de l'authentification.
/// Gère l'injection du token JWT, le rafraîchissement automatique (Refresh Token)
/// et la file d'attente des requêtes en cas d'expiration.
class AuthInterceptor extends Interceptor {
  final SecureStorageService _secureStorageService;
  final Dio _refreshDio; // Instance Dio sans intercepteur pour le refresh.

  /// Indique si un processus de rafraîchissement est déjà en cours.
  bool _isRefreshing = false;

  /// File d'attente pour stocker les requêtes échouées pendant le rafraîchissement.
  final List<({RequestOptions options, ErrorInterceptorHandler handler})>
  _failedRequestsQueue = [];

  AuthInterceptor(this._secureStorageService, this._refreshDio);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _secureStorageService.getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    return handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Si l'erreur n'est pas une 401 (Non autorisé), on passe à la suite.
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    // Si un rafraîchissement est déjà en cours, on ajoute la requête à la file d'attente.
    if (_isRefreshing) {
      _failedRequestsQueue.add((options: err.requestOptions, handler: handler));
      return;
    }

    _isRefreshing = true;

    try {
      final refreshToken = await _secureStorageService.getRefreshToken();

      if (refreshToken == null) {
        throw DioException(
          requestOptions: err.requestOptions,
          message: 'No refresh token available',
        );
      }

      // Tentative d'appel à l'API de rafraîchissement.
      final response = await _refreshDio.post(
        'accounts/token/refresh/',
        data: {'refresh': refreshToken},
      );

      // On récupère les nouveaux tokens.
      final newToken = response.data['access'];
      final newRefreshToken = response.data['refresh'];

      // Sauvegarde sécurisée.
      await _secureStorageService.saveToken(newToken);
      if (newRefreshToken != null) {
        await _secureStorageService.saveRefreshToken(newRefreshToken);
      }

      // 1. Relancer la requête initiale qui a échoué.
      final retryResponse = await _retryRequest(err.requestOptions, newToken);
      handler.resolve(retryResponse);

      // 2. Relancer toutes les requêtes en attente dans la file.
      for (final queuedRequest in _failedRequestsQueue) {
        final res = await _retryRequest(queuedRequest.options, newToken);
        queuedRequest.handler.resolve(res);
      }
      _failedRequestsQueue.clear();
    } catch (e) {
      // En cas d'échec du refresh, on vide la file et on déconnecte l'utilisateur.
      for (final queuedRequest in _failedRequestsQueue) {
        queuedRequest.handler.reject(err);
      }
      _failedRequestsQueue.clear();

      await _secureStorageService.deleteAll();
      // Ici, on pourrait déclencher une redirection vers le Login via un stream global.

      return handler.next(err);
    } finally {
      _isRefreshing = false;
    }
  }

  /// Méthode utilitaire pour rejouer une requête avec le nouveau token.
  Future<Response> _retryRequest(RequestOptions options, String token) {
    final newOptions = Options(
      method: options.method,
      headers: {...options.headers, 'Authorization': 'Bearer $token'},
      contentType: options.contentType,
      responseType: options.responseType,
    );

    return Dio(BaseOptions(baseUrl: options.baseUrl)).request(
      options.path,
      data: options.data,
      queryParameters: options.queryParameters,
      options: newOptions,
    );
  }
}
