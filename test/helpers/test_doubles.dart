import 'package:dio/dio.dart';
import 'package:digital_press/core/api/api_client.dart';
import 'package:digital_press/core/services/payment_service.dart';
import 'package:digital_press/core/storage/secure_storage_service.dart';
import 'package:digital_press/core/storage/storage_service.dart';

/// Faux stockage Hive en mémoire : évite d'initialiser Hive (indisponible
/// dans les tests de widgets) tout en gardant le même contrat que
/// [StorageService].
class FakeStorage implements StorageService {
  final Map<String, dynamic> _data = {};

  @override
  Future<void> init() async {}

  @override
  Future<void> set(String key, dynamic value) async => _data[key] = value;

  @override
  dynamic get(String key, {dynamic defaultValue}) =>
      _data[key] ?? defaultValue;

  @override
  Future<void> delete(String key) async => _data.remove(key);

  @override
  Future<void> clearAll() async => _data.clear();
}

/// Faux stockage sécurisé : aucun token présent (utilisateur déconnecté),
/// sauf si [token] est fourni.
class FakeSecureStorage implements SecureStorageService {
  FakeSecureStorage({this.token});

  String? token;

  @override
  Future<String?> getToken() async => token;

  @override
  Future<void> saveToken(String value) async => token = value;

  @override
  Future<String?> getRefreshToken() async => null;

  @override
  Future<void> saveRefreshToken(String value) async {}

  @override
  Future<void> deleteAll() async => token = null;
}

/// Faux client API : chaque requête passe par un handler fourni par le
/// test (jamais de vrai HTTP en test de widgets). [onPost] reçoit aussi le
/// corps envoyé pour permettre des assertions sur ce que le widget poste.
class FakeApiClient extends ApiClient {
  FakeApiClient({
    this.onGet,
    this.onPost,
    this.onPatch,
    this.onPut,
    this.onDelete,
  });

  final Future<Map<String, dynamic>> Function(String path)? onGet;
  final Future<Map<String, dynamic>> Function(String path, dynamic data)?
      onPost;
  final Future<Map<String, dynamic>> Function(String path, dynamic data)?
      onPatch;
  final Future<Map<String, dynamic>> Function(String path, dynamic data)?
      onPut;
  final Future<Map<String, dynamic>> Function(String path, dynamic data)?
      onDelete;

  final List<dynamic> postBodies = [];

  Response _ok(String path, Map<String, dynamic> data) => Response(
        requestOptions: RequestOptions(path: path),
        statusCode: 200,
        data: data,
      );

  @override
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    final data = onGet != null ? await onGet!(path) : <String, dynamic>{};
    return _ok(path, data);
  }

  @override
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    postBodies.add(data);
    final result =
        onPost != null ? await onPost!(path, data) : <String, dynamic>{};
    return _ok(path, result);
  }

  @override
  Future<Response> patch(
    String path, {
    dynamic data,
    Options? options,
  }) async {
    final result =
        onPatch != null ? await onPatch!(path, data) : <String, dynamic>{};
    return _ok(path, result);
  }

  @override
  Future<Response> put(
    String path, {
    dynamic data,
    Options? options,
  }) async {
    final result =
        onPut != null ? await onPut!(path, data) : <String, dynamic>{};
    return _ok(path, result);
  }

  @override
  Future<Response> delete(
    String path, {
    dynamic data,
    Options? options,
  }) async {
    final result =
        onDelete != null ? await onDelete!(path, data) : <String, dynamic>{};
    return _ok(path, result);
  }

  @override
  Future<HealthCheckResult> healthCheck() async =>
      const HealthCheckResult(isOnline: true, serverMessage: 'ok');
}

/// Faux service de paiement : [initiatePayment] répond immédiatement avec
/// la session fournie — permet de piloter l'écran de paiement sans polling
/// ni ouverture d'URL externe.
class FakePaymentService extends PaymentService {
  FakePaymentService({this.session})
      : super(FakeApiClient());

  PaymentSession? session;

  @override
  Future<PaymentSession?> initiatePayment({
    String? publicationId,
    int? abonnementId,
    required String phone,
    required double amount,
    required PaymentMethodType method,
    bool isSubscription = false,
    bool isRecharge = false,
  }) async {
    return session;
  }

  @override
  Future<bool> waitForPaymentCompletion(
    String reference, {
    Duration timeout = const Duration(minutes: 5),
  }) async {
    return true;
  }
}
