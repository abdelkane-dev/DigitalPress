import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:digital_press/core/api/api_client.dart';
import 'package:digital_press/core/storage/secure_storage_service.dart';
import 'package:digital_press/core/storage/storage_service.dart';
import 'package:digital_press/main.dart';

/// Faux stockage Hive en mémoire : évite d'initialiser Hive (indisponible
/// dans les tests de widgets) tout en gardant le même contrat que
/// [StorageService].
class _FakeStorage implements StorageService {
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

/// Faux stockage sécurisé : aucun token présent (utilisateur déconnecté).
class _FakeSecureStorage implements SecureStorageService {
  @override
  Future<String?> getToken() async => null;

  @override
  Future<void> saveToken(String token) async {}

  @override
  Future<String?> getRefreshToken() async => null;

  @override
  Future<void> saveRefreshToken(String token) async {}

  @override
  Future<void> deleteAll() async {}
}

/// Faux client API : toutes les requêtes répondent immédiatement avec une
/// liste vide, sans passer par Dio — indispensable pour que le test de
/// widgets ne laisse aucun Timer Dio en attente (HTTP réel interdit en test).
class _FakeApiClient extends ApiClient {
  @override
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async =>
      _emptyResponse(path);

  @override
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async =>
      _emptyResponse(path);

  @override
  Future<Response> patch(
    String path, {
    dynamic data,
    Options? options,
  }) async =>
      _emptyResponse(path);

  @override
  Future<Response> put(
    String path, {
    dynamic data,
    Options? options,
  }) async =>
      _emptyResponse(path);

  @override
  Future<Response> delete(
    String path, {
    dynamic data,
    Options? options,
  }) async =>
      _emptyResponse(path);

  @override
  Future<HealthCheckResult> healthCheck() async =>
      const HealthCheckResult(isOnline: false);

  Response _emptyResponse(String path) => Response(
        requestOptions: RequestOptions(path: path),
        statusCode: 200,
        data: {'results': <dynamic>[]},
      );
}

void main() {
  testWidgets('DigitalPress app launches without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(_FakeApiClient()),
          storageServiceProvider.overrideWithValue(_FakeStorage()),
          secureStorageServiceProvider.overrideWithValue(_FakeSecureStorage()),
        ],
        child: const DigitalPressApp(),
      ),
    );

    // Laisse les post-frame callbacks (chargement initial de l'accueil)
    // et les micro-tâches se terminer pour ne laisser aucun timer en attente.
    await tester.pump();

    // Verify that the app renders without crashing
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
