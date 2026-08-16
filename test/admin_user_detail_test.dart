import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:digital_press/core/api/api_client.dart';
import 'package:digital_press/core/storage/secure_storage_service.dart';
import 'package:digital_press/core/storage/storage_service.dart';
import 'package:digital_press/screens/admin/admin_user_detail_screen.dart';

import 'helpers/test_doubles.dart';

/// Réponse type du backend pour GET /accounts/admin/users/{pk}/detail/ —
/// même forme que celle servie par AdminUserDetailView (identité, rôle,
/// stats, transactions récentes, historique de modération, éditeur).
Map<String, dynamic> _userDetailJson() => {
      'id': 1,
      'username': 'yao',
      'name': 'Yao Kouassi',
      'email': 'yao@example.com',
      'phone': '+225 07 00 00 00',
      'role': 'reader',
      'is_verified': true,
      'is_active': true,
      'date_joined': '2026-01-10T09:30:00Z',
      'last_login': '2026-08-15T18:00:00Z',
      'purchases_count': 3,
      'total_spent': '15000.00',
      'transactions_count': 5,
      'publisher': null,
      'recent_transactions': [
        {
          'type_transaction': 'purchase',
          'montant_brut': '5000.00',
          'status': 'success',
        },
      ],
      'status_history': [
        {
          'action': 'suspend',
          'reason': 'Contenu signalé',
          'created_at': '2026-07-01T10:00:00Z',
          'performed_by': 'admin',
        },
      ],
    };

void main() {
  testWidgets(
      'la page de détail admin affiche identité, statut, transactions et actions',
      (WidgetTester tester) async {
    final api = FakeApiClient(
      onGet: (path) async {
        if (path.contains('admin/users/1/detail')) return _userDetailJson();
        return <String, dynamic>{};
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          storageServiceProvider.overrideWithValue(FakeStorage()),
          secureStorageServiceProvider.overrideWithValue(FakeSecureStorage()),
        ],
        child: const MaterialApp(
          home: AdminUserDetailScreen(userId: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Identité + rôle.
    expect(find.text('Détails du compte'), findsOneWidget);
    expect(find.text('Yao Kouassi'), findsOneWidget);
    expect(find.text('@yao'), findsOneWidget);
    expect(find.text('yao@example.com'), findsOneWidget);
    expect(find.text('Lecteur'), findsOneWidget);

    // Statut actif.
    expect(find.text('Statut du compte'), findsOneWidget);
    expect(find.text('Actif'), findsOneWidget);

    // Informations (achats / transactions).
    expect(find.text('Achats réussis'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    // La page défile (ListView paresseuse) : on fait défiler jusqu'aux
    // sections du bas pour les vérifier.
    await tester.scrollUntilVisible(
      find.text('Achats & paiements récents'),
      200,
    );
    expect(find.text('Achat'), findsOneWidget);

    // Historique de modération (suspension passée).
    await tester.scrollUntilVisible(
      find.text('Historique de modération'),
      200,
    );
    expect(find.textContaining('Suspendu —'), findsOneWidget);
    expect(find.text('Contenu signalé'), findsOneWidget);

    // Actions disponibles pour un compte actif.
    await tester.scrollUntilVisible(
      find.text('Bannir le compte'),
      200,
    );
    expect(find.text('Suspendre le compte'), findsOneWidget);
    expect(find.text('Bannir le compte'), findsOneWidget);
  });

  testWidgets(
      'bannir un compte exige un motif puis POST l’action et confirme',
      (WidgetTester tester) async {
    final api = FakeApiClient(
      onGet: (path) async {
        if (path.contains('admin/users/1/detail')) return _userDetailJson();
        return <String, dynamic>{};
      },
      onPost: (path, data) async {
        if (path.contains('admin/users/1/action')) {
          return {'status': 'ok'};
        }
        return <String, dynamic>{};
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          storageServiceProvider.overrideWithValue(FakeStorage()),
          secureStorageServiceProvider.overrideWithValue(FakeSecureStorage()),
        ],
        child: const MaterialApp(
          home: AdminUserDetailScreen(userId: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Ouvre le dialogue de bannissement (bouton en bas de page).
    await tester.scrollUntilVisible(
      find.text('Bannir le compte'),
      200,
    );
    await tester.tap(find.text('Bannir le compte'));
    await tester.pumpAndSettle();
    expect(find.text('Bannir ce compte ?'), findsOneWidget);

    // Le motif est obligatoire : sans motif, le bannissement est refusé
    // (aucun POST, le dialogue reste ouvert).
    await tester.tap(find.widgetWithText(ElevatedButton, 'Bannir'));
    await tester.pump();
    expect(api.postBodies, isEmpty);
    expect(find.text('Bannir ce compte ?'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Motif (obligatoire)'),
      'Fraude détectée sur plusieurs achats',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Bannir'));
    await tester.pumpAndSettle();

    // L'action est postée avec le motif, et la confirmation s'affiche.
    expect(api.postBodies, isNotEmpty);
    expect(api.postBodies.last, {
      'action': 'ban',
      'reason': 'Fraude détectée sur plusieurs achats',
    });
    expect(find.text('Compte banni.'), findsOneWidget);
  });
}
