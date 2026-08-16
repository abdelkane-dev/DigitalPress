/// Implémentation mobile du téléchargement utilisant flutter_downloader.
/// Ce fichier n'est importé que sur les plateformes natives (pas web).
library;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_downloader/flutter_downloader.dart';

Future<void> initializeDownloader() async {
  // ─── SÉCURITÉ ─────────────────────────────────────────────────────────
  // ignoreSsl=true (précédemment codé en dur) désactivait la vérification
  // des certificats SSL pour TOUS les téléchargements — un attaquant en
  // interception réseau (MITM) aurait pu servir un faux certificat sans que
  // l'app le détecte, ce qui annulait la protection apportée par le
  // durcissement App Transport Security / cleartext déjà fait par ailleurs.
  // debug=true était aussi codé en dur (logs verbeux même en production).
  await FlutterDownloader.initialize(debug: kDebugMode, ignoreSsl: false);
}

void registerCallback(void Function(String, int, int) callback) {
  FlutterDownloader.registerCallback(callback);
}

Future<String?> enqueueDownload({
  required String url,
  required String savedDir,
  required String fileName,
}) async {
  final taskId = await FlutterDownloader.enqueue(
    url: url,
    savedDir: savedDir,
    fileName: fileName,
    showNotification: true,
    openFileFromNotification: false,
    saveInPublicStorage: false,
  );
  return taskId;
}

Future<void> cancelDownload(String taskId) async {
  await FlutterDownloader.cancel(taskId: taskId);
}
