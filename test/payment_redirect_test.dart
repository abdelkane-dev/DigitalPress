import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:digital_press/core/api/api_client.dart';
import 'package:digital_press/core/services/download_service.dart';
import 'package:digital_press/core/services/payment_service.dart';
import 'package:digital_press/core/storage/secure_storage_service.dart';
import 'package:digital_press/core/storage/storage_service.dart';
import 'package:digital_press/screens/payment/payment_screen.dart';
import 'package:digital_press/screens/reader/reader_screen.dart';

import 'helpers/test_doubles.dart';

/// Faux service de téléchargement : Hive n'est pas initialisé en test de
/// widgets, or ReaderViewModel interroge le chemin local au chargement.
class _FakeDownloadService extends DownloadService {
  @override
  Future<String?> getDownloadLocation(String journalId) async => null;

  @override
  Future<void> saveDownloadLocation(String journalId, String path) async {}
}

void main() {
  testWidgets(
      'après un achat réussi, « Lire l’article » remplace l’écran de paiement par le lecteur de l’article',
      (WidgetTester tester) async {
    // Le paiement est déjà confirmé dès l'initiation (session 'success',
    // comme un débit de portefeuille) : le succès s'affiche sans polling.
    final paymentService = FakePaymentService(
      session: PaymentSession(
        reference: 'TEST-REF-001',
        paymentUrl: '',
        status: 'success',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(FakeApiClient()),
          storageServiceProvider.overrideWithValue(FakeStorage()),
          secureStorageServiceProvider.overrideWithValue(FakeSecureStorage()),
          downloadServiceProvider.overrideWithValue(_FakeDownloadService()),
          paymentServiceProvider.overrideWithValue(paymentService),
        ],
        child: MaterialApp(
          // Un écran d'accueil factice : l'écran de paiement est poussé
          // dessus, comme dans le parcours réel (accueil → article → payer).
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PaymentScreen(
                        journalId: '42',
                        journalTitle: 'Le Journal du Mali',
                        price: 1000,
                        paymentMethod: PaymentMethodType.wallet,
                        paymentMethodName: 'Portefeuille',
                      ),
                    ),
                  ),
                  child: const Text('pousser le paiement'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Ouvre l'écran de paiement.
    await tester.tap(find.text('pousser le paiement'));
    await tester.pumpAndSettle();
    expect(find.text('Paiement'), findsOneWidget);

    // Confirme l'achat (portefeuille : aucun champ à remplir).
    await tester.tap(find.text('Confirmer — 1000 FCFA'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Le dialogue de succès s'affiche avec le bouton de lecture directe.
    expect(find.text('Achat réussi !'), findsOneWidget);
    expect(find.text('Ouvrir l’article'), findsOneWidget);

    // Tap sur « Ouvrir l'article » → l'écran de paiement est REMPLACÉ par le
    // lecteur de l'article acheté (redirection demandée explicitement).
    await tester.tap(find.text('Ouvrir l’article'));
    await tester.pumpAndSettle();

    expect(find.byType(ReaderScreen), findsOneWidget);
    expect(find.byType(PaymentScreen), findsNothing);

    // Laisse expirer le minuteur d'ouverture automatique de l'article
    // (déjà consommé par le bouton — le garde anti-double navigation
    // l'ignore) pour ne laisser aucun timer en attente en fin de test.
    await tester.pump(const Duration(milliseconds: 1400));
  });

  testWidgets(
      'une recharge de portefeuille ne redirige PAS vers un article (isRecharge)',
      (WidgetTester tester) async {
    final paymentService = FakePaymentService(
      session: PaymentSession(
        reference: 'TEST-REF-002',
        paymentUrl: '',
        status: 'success',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(FakeApiClient()),
          storageServiceProvider.overrideWithValue(FakeStorage()),
          secureStorageServiceProvider.overrideWithValue(FakeSecureStorage()),
          downloadServiceProvider.overrideWithValue(_FakeDownloadService()),
          paymentServiceProvider.overrideWithValue(paymentService),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PaymentScreen(
                        journalTitle: 'Recharge',
                        price: 2000,
                        paymentMethod: PaymentMethodType.wallet,
                        paymentMethodName: 'Portefeuille',
                        isRecharge: true,
                      ),
                    ),
                  ),
                  child: const Text('pousser le paiement'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('pousser le paiement'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmer — 2000 FCFA'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Achat réussi !'), findsOneWidget);
    // Une recharge affiche « Fermer » (pas d'article à ouvrir) : le bouton
    // referme le dialogue puis l'écran de paiement, retour à l'écran
    // précédent — jamais de redirection vers un lecteur.
    await tester.tap(find.text('Fermer'));
    await tester.pumpAndSettle();

    // Pas de lecteur : la recharge n'a pas d'article associé.
    expect(find.byType(ReaderScreen), findsNothing);
    expect(find.byType(PaymentScreen), findsNothing);
  });
}
