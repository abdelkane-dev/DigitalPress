import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:logger/logger.dart';

final downloadServiceProvider = Provider<DownloadService>((ref) {
  return DownloadService();
});

class DownloadService {
  final _logger = Logger();
  final ReceivePort _port = ReceivePort();

  DownloadService() {
    _bindBackgroundIsolate();
  }

  void _bindBackgroundIsolate() {
    bool isSuccess = IsolateNameServer.registerPortWithName(
      _port.sendPort,
      'downloader_send_port',
    );
    if (!isSuccess) {
      _unbindBackgroundIsolate();
      _bindBackgroundIsolate();
      return;
    }
    _port.listen((dynamic data) {
      String id = data[0];
      int status = data[1];
      int progress = data[2];

      // Update logic would go here if we were using a stream/callback
      _logger.d('Download task: $id, status: $status, progress: $progress');
    });
  }

  void _unbindBackgroundIsolate() {
    IsolateNameServer.removePortNameMapping('downloader_send_port');
  }

  static void downloadCallback(String id, int status, int progress) {
    final SendPort? send = IsolateNameServer.lookupPortByName(
      'downloader_send_port',
    );
    send?.send([id, status, progress]);
  }

  Future<void> initialize() async {
    await FlutterDownloader.initialize(debug: true, ignoreSsl: true);
    FlutterDownloader.registerCallback(downloadCallback);
  }

  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (status.isGranted) return true;

      // Android 13+ permission
      if (await Permission.photos.request().isGranted) return true;
      if (await Permission.videos.request().isGranted) return true;
      if (await Permission.audio.request().isGranted) return true;

      // For Android 10+ scoped storage, we might not need explicit storage permission
      // if using app-specific directories, but good to check.
    }
    return true; // iOS doesn't need explicit storage permission for app sandbox
  }

  Future<String?> downloadJournal(String url, String fileName) async {
    final hasPermission = await requestPermissions();
    if (!hasPermission) {
      _logger.w('Permission de stockage refusée');
      return null;
    }

    final directory = await getApplicationDocumentsDirectory();
    final savedDir = directory.path;

    try {
      final taskId = await FlutterDownloader.enqueue(
        url: url,
        savedDir: savedDir,
        fileName: fileName,
        showNotification: true,
        openFileFromNotification: false,
        saveInPublicStorage: false,
      );
      return taskId;
    } catch (e) {
      _logger.e('Erreur lors du téléchargement: $e');
      return null;
    }
  }

  Future<void> saveDownloadLocation(String journalId, String path) async {
    final box = await Hive.openBox('downloads');
    await box.put(journalId, path);
  }

  Future<String?> getDownloadLocation(String journalId) async {
    final box = await Hive.openBox('downloads');
    return box.get(journalId) as String?;
  }

  Future<void> cancelDownload(String taskId) async {
    await FlutterDownloader.cancel(taskId: taskId);
  }
}
