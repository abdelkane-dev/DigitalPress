import 'package:digital_press/core/api/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildHealthStatusMessage', () {
    test('renvoie un message vide quand le service répond (production)', () {
      expect(
        buildHealthStatusMessage(
          isOnline: true,
          serverMessage: 'digital-press-api • ok • v1',
        ),
        '',
      );
    });

    test('renvoie un message simple quand le serveur est indisponible', () {
      expect(
        buildHealthStatusMessage(isOnline: false, serverMessage: null),
        'Le serveur est indisponible',
      );
    });
  });
}
