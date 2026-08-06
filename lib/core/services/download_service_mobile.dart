/// Implémentation mobile du téléchargement utilisant flutter_downloader.
/// Ce fichier n'est importé que sur les plateformes natives (pas web).
library;

import 'package:flutter_downloader/flutter_downloader.dart';

Future<void> initializeDownloader() async {
  await FlutterDownloader.initialize(debug: true, ignoreSsl: true);
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
