import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:digital_press/core/api/api_client.dart';
import 'package:digital_press/core/storage/secure_storage_service.dart';
import 'package:digital_press/core/storage/storage_service.dart';
import 'package:digital_press/widgets/withdrawal_request_sheet.dart';

import 'helpers/test_doubles.dart';

void main() {
  testWidgets(
      'flux OTP de retrait : moyen → numéro/montant → code → validation renvoie le bon résultat',
      (WidgetTester tester) async {
    // Le backend répond au POST /paiements/retrait/otp/ avec un destinataire
    // masqué, comme en production.
    final api = FakeApiClient(
      onPost: (path, data) async {
        if (path.contains('retrait/otp')) {
          return {
            'message': 'Un code de confirmation a été envoyé par email.',
            'channel': 'email',
            'destination': '70*****',
            'expires_in_minutes': 15,
          };
        }
        return <String, dynamic>{};
      },
    );

    Map<String, String>? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          storageServiceProvider.overrideWithValue(FakeStorage()),
          secureStorageServiceProvider.overrideWithValue(FakeSecureStorage()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await showWithdrawalRequestSheet(context);
                  },
                  child: const Text('ouvrir le retrait'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // ─── Étape 1 : choix du moyen de retrait ─────────────────────────────
    await tester.tap(find.text('ouvrir le retrait'));
    await tester.pumpAndSettle();
    expect(find.text('Retirer des fonds'), findsOneWidget);
    expect(find.text('Wave'), findsOneWidget);

    await tester.tap(find.text('Wave'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmation'), findsNothing);

    // ─── Étape 2 : numéro + montant ─────────────────────────────────────
    await tester.enterText(
      find.byWidgetPredicate((w) =>
          w is TextField &&
          (w.decoration?.labelText ?? '').contains('Numéro Wave')),
      '+223 70 00 00 00',
    );
    await tester.enterText(
      find.byWidgetPredicate((w) =>
          w is TextField &&
          (w.decoration?.labelText ?? '').contains('Montant à recevoir')),
      '5000',
    );

    // Le choix du canal (email / SMS) est bien proposé avant l'envoi.
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('SMS'), findsOneWidget);

    // ─── Étape 3 : demande du code (canal email) ────────────────────────
    // Pas de pumpAndSettle ici : le compte à rebours « Renvoyer le code »
    // est un timer périodique qui ne se stabilise jamais.
    await tester.tap(find.text('Envoyer le code de confirmation'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Confirmation'), findsOneWidget);
    expect(find.text('Code envoyé à 70***** (valable 15 min).'), findsOneWidget);

    // ─── Étape 4 : saisie du code + validation ──────────────────────────
    await tester.enterText(
      find.byWidgetPredicate((w) =>
          w is TextField && (w.decoration?.hintText ?? '') == '••••••'),
      '123456',
    );
    await tester.tap(find.text('Valider la demande de retrait'));
    await tester.pumpAndSettle(); // la feuille se referme, le timer est libéré

    // Le résultat transmis au caller contient tout ce qu'il faut pour créer
    // la demande côté serveur, dont le code OTP saisi.
    expect(result, {
      'mode': 'wave',
      'numero': '+223 70 00 00 00',
      'montant': '5000',
      'otp_code': '123456',
    });

    // Le code OTP a bien été demandé au backend avec le canal choisi.
    expect(api.postBodies, isNotEmpty);
    expect(api.postBodies.last, {'channel': 'email'});
  });

  testWidgets('flux OTP : un code incomplet est refusé sans fermer la feuille',
      (WidgetTester tester) async {
    final api = FakeApiClient(
      onPost: (path, data) async => {
        'message': 'Un code de confirmation a été envoyé par sms.',
        'channel': 'sms',
        'destination': '+223 ****',
        'expires_in_minutes': 15,
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          storageServiceProvider.overrideWithValue(FakeStorage()),
          secureStorageServiceProvider.overrideWithValue(FakeSecureStorage()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showWithdrawalRequestSheet(context),
                  child: const Text('ouvrir le retrait'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ouvrir le retrait'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Orange Money'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byWidgetPredicate((w) =>
          w is TextField &&
          (w.decoration?.labelText ?? '').contains('Numéro Orange Money')),
      '+223 70 00 00 00',
    );
    await tester.enterText(
      find.byWidgetPredicate((w) =>
          w is TextField &&
          (w.decoration?.labelText ?? '').contains('Montant à recevoir')),
      '2500',
    );

    // Choix du canal SMS puis demande du code.
    await tester.tap(find.text('SMS'));
    await tester.pump();
    await tester.tap(find.text('Envoyer le code de confirmation'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Code trop court (3 chiffres) : message d'erreur, la feuille reste
    // ouverte et rien n'est renvoyé.
    await tester.enterText(
      find.byWidgetPredicate((w) =>
          w is TextField && (w.decoration?.hintText ?? '') == '••••••'),
      '123',
    );
    await tester.tap(find.text('Valider la demande de retrait'));
    await tester.pump();

    expect(
      find.text('Veuillez saisir le code à 6 chiffres reçu.'),
      findsOneWidget,
    );
    expect(find.text('Confirmation'), findsOneWidget);

    // Le POST du code a bien utilisé le canal SMS demandé.
    expect(api.postBodies, isNotEmpty);
    expect(api.postBodies.last, {'channel': 'sms'});

    // Referme la feuille (libère le compte à rebours) pour clore le test
    // sans timer résiduel.
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
  });
}
