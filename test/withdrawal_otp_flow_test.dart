import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:digital_press/core/api/api_client.dart';
import 'package:digital_press/core/storage/secure_storage_service.dart';
import 'package:digital_press/core/storage/storage_service.dart';
import 'package:digital_press/widgets/withdrawal_request_sheet.dart';

import 'helpers/test_doubles.dart';

/// Helper to open the withdrawal sheet and select a payment method, then
/// fill in the phone number and amount fields.  Returns after the form
/// step is fully populated so the caller can interact with the channel
/// selector and submit button.
Future<void> _openSheetAndFillForm(
  WidgetTester tester, {
  required String methodLabel,
  required String phone,
  required String amount,
}) async {
  // Open the bottom sheet.
  await tester.tap(find.text('ouvrir le retrait'));
  await tester.pumpAndSettle();
  expect(find.text('Retirer des fonds'), findsOneWidget);

  // Scroll to make the method tile visible then tap it.
  await tester.ensureVisible(find.text(methodLabel));
  await tester.tap(find.text(methodLabel));
  await tester.pumpAndSettle();

  // Fill phone number – scroll into view first because the form is long.
  final phoneField = find.byWidgetPredicate((w) =>
      w is TextField &&
      (w.decoration?.hintText ?? '').startsWith('Ex: X'));
  await tester.ensureVisible(phoneField);
  await tester.enterText(phoneField, phone);

  // Fill amount.
  final amountField = find.byWidgetPredicate((w) =>
      w is TextField &&
      (w.decoration?.hintText ?? '').startsWith('Ex: 5'));
  await tester.ensureVisible(amountField);
  await tester.enterText(amountField, amount);
}

void main() {
  testWidgets(
      'flux OTP de retrait : moyen → numéro/montant → code → validation renvoie le bon résultat',
      (WidgetTester tester) async {
    // Use a generous surface so the bottom sheet content (which is 88 %
    // of screen height) can render all form widgets within bounds.
    await tester.binding.setSurfaceSize(const Size(800, 6000));
    addTearDown(() async =>
        await tester.binding.setSurfaceSize(const Size(800, 600)));

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
    await _openSheetAndFillForm(
      tester,
      methodLabel: 'Wave',
      phone: '70000000',
      amount: '5000',
    );

    // Le choix du canal (email / SMS) est bien proposé avant l'envoi.
    expect(find.text('Email'), findsWidgets);
    expect(find.text('SMS'), findsOneWidget);

    // ─── Étape 3 : demande du code (canal email) ────────────────────────
    // Scroll the "Envoyer" button into view before tapping.
    final sendBtn = find.text('Envoyer le code de confirmation');
    await tester.ensureVisible(sendBtn);
    await tester.tap(sendBtn);
    // Pas de pumpAndSettle ici : le compte à rebours « Renvoyer le code »
    // est un timer périodique qui ne se stabilise jamais.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Confirmation'), findsOneWidget);
    expect(find.text('Code envoyé à 70***** (valable 15 min)'), findsOneWidget);

    // ─── Étape 4 : saisie du code + validation ──────────────────────────
    final otpField = find.byWidgetPredicate(
        (w) => w is TextField && (w.decoration?.hintText ?? '') == '••••••');
    await tester.ensureVisible(otpField);
    await tester.enterText(otpField, '123456');

    final validateBtn = find.text('Valider la demande de retrait');
    await tester.ensureVisible(validateBtn);
    await tester.tap(validateBtn);
    await tester.pumpAndSettle(); // la feuille se referme, le timer est libéré

    expect(result, {
      'mode': 'wave',
      'numero': '+223 70000000',
      'montant': '5000',
      'otp_code': '123456',
    });

    expect(api.postBodies, isNotEmpty);
    expect(api.postBodies.last, {'channel': 'email'});
  });

  testWidgets('flux OTP : un code incomplet est refusé sans fermer la feuille',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 6000));
    addTearDown(() async =>
        await tester.binding.setSurfaceSize(const Size(800, 600)));

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

    // Fill form for Orange Money.
    await _openSheetAndFillForm(
      tester,
      methodLabel: 'Orange Money',
      phone: '+223 70 00 00 00',
      amount: '2500',
    );

    // Choix du canal SMS puis demande du code.
    await tester.ensureVisible(find.text('SMS'));
    await tester.tap(find.text('SMS'));
    await tester.pump();

    final sendBtn = find.text('Envoyer le code de confirmation');
    await tester.ensureVisible(sendBtn);
    await tester.tap(sendBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Code trop court (3 chiffres) : message d'erreur, la feuille reste
    // ouverte et rien n'est renvoyé.
    final otpField = find.byWidgetPredicate(
        (w) => w is TextField && (w.decoration?.hintText ?? '') == '••••••');
    await tester.ensureVisible(otpField);
    await tester.enterText(otpField, '123');

    final validateBtn = find.text('Valider la demande de retrait');
    await tester.ensureVisible(validateBtn);
    await tester.tap(validateBtn);
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
    final closeBtn = find.byIcon(Icons.close_rounded);
    await tester.ensureVisible(closeBtn);
    await tester.tap(closeBtn);
    await tester.pumpAndSettle();
  });
}
