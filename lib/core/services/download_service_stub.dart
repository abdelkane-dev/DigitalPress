/// Stub pour le web — flutter_downloader n'est pas disponible.
/// Ces fonctions ne devraient jamais être appelées sur le web
/// car download_service.dart vérifie kIsWeb en amont.
library;


Future<void> initializeDownloader() async {}

void registerCallback(void Function(String, int, int) callback) {}

Future<String?> enqueueDownload({
  required String url,
  required String savedDir,
  required String fileName,
}) async {
  return null;
}

Future<void> cancelDownload(String taskId) async {}
