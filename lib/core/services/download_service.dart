import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:logger/logger.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/platform_helper.dart';

// Import conditionnel : flutter_downloader n'est disponible que sur mobile.
// On l'importe conditionnellement via un wrapper.
import 'download_service_mobile.dart'
    if (dart.library.html) 'download_service_stub.dart' as mobile_downloader;

final downloadServiceProvider = Provider<DownloadService>((ref) {
  return DownloadService();
});

class DownloadService {
  final _logger = Logger();

  DownloadService() {
    if (!kIsWeb && PlatformHelper.supportsFlutterDownloader) {
      _bindBackgroundIsolate();
    }
  }

  // ─── Background Isolate (mobile uniquement) ──────────────────────────────

  final ReceivePort _port = ReceivePort();

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
      _logger.d('Download task: $id, status: $status, progress: $progress');
    });
  }

  void _unbindBackgroundIsolate() {
    IsolateNameServer.removePortNameMapping('downloader_send_port');
  }

  @pragma('vm:entry-point')
  static void downloadCallback(String id, int status, int progress) {
    final SendPort? send = IsolateNameServer.lookupPortByName(
      'downloader_send_port',
    );
    send?.send([id, status, progress]);
  }

  // ─── Initialisation ──────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (kIsWeb) return;
    if (PlatformHelper.supportsFlutterDownloader) {
      await mobile_downloader.initializeDownloader();
      mobile_downloader.registerCallback(downloadCallback);
    }
    // Sur desktop, pas d'initialisation spéciale nécessaire (on utilise Dio).
  }

  // ─── Permissions ─────────────────────────────────────────────────────────

  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;

    if (PlatformHelper.isAndroid) {
      // ─── BUG CORRIGÉ ────────────────────────────────────────────────
      // Avant : que l'utilisateur accepte ou refuse TOUTES les demandes,
      // la fonction retournait quand même `true` inconditionnellement
      // (le `return true` final n'était jamais atteint que par les
      // plateformes non-Android, mais s'appliquait aussi après un échec
      // Android faute de `return false` explicite). Le code appelant ne
      // pouvait donc jamais détecter un refus réel de permission.
      final storageStatus = await Permission.storage.request();
      if (storageStatus.isGranted) return true;

      // Android 13+ : permissions granulaires. Permission.photos ET
      // Permission.videos correspondent bien à des permissions déclarées
      // (READ_MEDIA_IMAGES, READ_MEDIA_VIDEO) — la plateforme distribue
      // réellement des publications vidéo (Publication.video_url), donc
      // les deux sont légitimes. Permission.audio n'a pas d'équivalent
      // manifeste (aucun contenu audio sur la plateforme) et échouerait
      // silencieusement sur Android 13+, donc on ne la demande pas.
      final photosStatus = await Permission.photos.request();
      if (photosStatus.isGranted) return true;
      final videosStatus = await Permission.videos.request();
      return videosStatus.isGranted;
    }

    // iOS, macOS, Windows, Linux — pas de permission de stockage nécessaire
    // pour l'app sandbox / dossier documents de l'application.
    return true;
  }

  // ─── Téléchargement ──────────────────────────────────────────────────────

  /// Télécharge un journal.
  /// - Sur mobile (Android/iOS) : utilise flutter_downloader avec notification
  /// - Sur desktop (macOS/Windows/Linux) : utilise Dio download direct
  Future<String?> downloadJournal(String url, String fileName) async {
    if (kIsWeb) {
      final uri = Uri.tryParse(url);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _logger.e('Impossible de lancer l\'URL sur le web: $url');
      }
      return null;
    }

    final hasPermission = await requestPermissions();
    if (!hasPermission) {
      _logger.w('Permission de stockage refusée');
      return null;
    }

    final directory = await getApplicationDocumentsDirectory();
    final savedDir = directory.path;

    try {
      if (PlatformHelper.supportsFlutterDownloader) {
        // ── Mobile : flutter_downloader ─────────────────────────────────
        final taskId = await mobile_downloader.enqueueDownload(
          url: url,
          savedDir: savedDir,
          fileName: fileName,
        );
        return taskId;
      } else {
        // ── Desktop : Dio download ─────────────────────────────────────
        // We avoid importing dart:io directly for path separators.
        // Windows uses '\', others use '/'. We'll just use '/'.
        final filePath = '$savedDir/$fileName';
        final dio = Dio();
        await dio.download(url, filePath);
        _logger.i('Fichier téléchargé (desktop) : $filePath');
        return filePath;
      }
    } catch (e) {
      _logger.e('Erreur lors du téléchargement: $e');
      return null;
    }
  }

  // ─── Cache local (Hive) ──────────────────────────────────────────────────

  Future<void> saveDownloadLocation(String journalId, String path) async {
    final box = await Hive.openBox('downloads');
    await box.put(journalId, path);
  }

  Future<String?> getDownloadLocation(String journalId) async {
    final box = await Hive.openBox('downloads');
    return box.get(journalId) as String?;
  }

  // ─── Annulation ──────────────────────────────────────────────────────────

  Future<void> cancelDownload(String taskId) async {
    if (PlatformHelper.supportsFlutterDownloader) {
      await mobile_downloader.cancelDownload(taskId);
    }
    // Sur desktop, l'annulation d'un Dio download devrait utiliser un
    // CancelToken — à implémenter si besoin.
  }
}
