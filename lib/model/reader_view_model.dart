import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../core/services/security_service.dart';
import '../core/services/download_service.dart';
import '../core/storage/storage_service.dart';
import '../core/services/publication_service.dart';
import '../core/exceptions/failures.dart';

/// Représente l'état métier de l'écran du lecteur PDF.
class ReaderState {
  final bool isLoading; // Indique si le PDF est en cours de chargement.
  final int currentPage; // Index de la page actuelle.
  final int totalPages; // Nombre total de pages du document.
  final String? errorMessage; // Message d'erreur éventuel.
  final bool
  isSubscribed; // Indique si l'utilisateur possède l'abonnement requis.
  final String? localFilePath; // Chemin du fichier local si téléchargé.
  final bool isDownloading; // Indique si un téléchargement est en cours.
  final bool isNightMode; // Mode nuit activé ou non.
  final String? fileUrl; // URL réelle et vérifiée du document à afficher.
  final bool accessDenied; // Vrai si le backend a refusé l'accès complet.

  ReaderState({
    this.isLoading = true,
    this.currentPage = 0,
    this.totalPages = 0,
    this.errorMessage,
    this.isSubscribed = false,
    this.localFilePath,
    this.isDownloading = false,
    this.isNightMode = false,
    this.fileUrl,
    this.accessDenied = false,
  });

  /// Méthode utilitaire pour créer une nouvelle instance d'état avec des modifications.
  ReaderState copyWith({
    bool? isLoading,
    int? currentPage,
    int? totalPages,
    String? errorMessage,
    bool? isSubscribed,
    String? localFilePath,
    bool? isDownloading,
    bool? isNightMode,
    String? fileUrl,
    bool? accessDenied,
  }) {
    return ReaderState(
      isLoading: isLoading ?? this.isLoading,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      errorMessage: errorMessage ?? this.errorMessage,
      isSubscribed: isSubscribed ?? this.isSubscribed,
      localFilePath: localFilePath ?? this.localFilePath,
      isDownloading: isDownloading ?? this.isDownloading,
      isNightMode: isNightMode ?? this.isNightMode,
      fileUrl: fileUrl ?? this.fileUrl,
      accessDenied: accessDenied ?? this.accessDenied,
    );
  }
}

/// Contrôleur logique de l'écran Reader.
/// Famille Riverpod : chaque journal (journalId) possède son propre état.
class ReaderViewModel extends StateNotifier<ReaderState> {
  final SecurityService _securityService;
  final DownloadService _downloadService;
  final StorageService _storageService;
  final PublicationService _publicationService;
  final String journalId;

  ReaderViewModel(
    this._securityService,
    this._downloadService,
    this._storageService,
    this._publicationService,
    this.journalId,
  ) : super(ReaderState()) {
    _init();
  }

  /// Initialise l'écran en activant les protections DRM (anti-capture) et en
  /// récupérant l'URL réelle du document, vérifiée côté serveur.
  Future<void> _init() async {
    _securityService.setSecureMode(true);
    await _checkDownloadStatus();
    _restoreReadingPosition();
    await _loadFileUrl();
  }

  Future<void> _loadFileUrl() async {
    try {
      final id = int.tryParse(journalId);
      if (id == null) {
        state = state.copyWith(
            isLoading: false, errorMessage: 'Identifiant de publication invalide.');
        return;
      }
      
      String? url;
      try {
        url = await _publicationService.getProtectedFileUrl(id);
      } catch (e) {
        // En cas de panne de réseau, si on a un fichier local, on l'affiche directement.
        if (state.localFilePath != null) {
          state = state.copyWith(isLoading: false);
          return;
        }
        rethrow;
      }

      state = state.copyWith(fileUrl: url, accessDenied: false);

      // Si on a l'URL mais pas encore le fichier en local, on le télécharge silencieusement en tâche de fond.
      if (state.localFilePath == null && url.isNotEmpty) {
        _cacheFileInBackground(id, url);
      } else {
        state = state.copyWith(isLoading: false);
      }
    } on Failure catch (e) {
      if (state.localFilePath != null) {
        state = state.copyWith(isLoading: false);
        return;
      }
      if (e.message.contains('Abonnement') ||
          e.message.contains('achat') ||
          e.message.contains('requis') ||
          e.message.contains('403')) {
        state = state.copyWith(isLoading: false, accessDenied: true);
      } else {
        state = state.copyWith(isLoading: false, errorMessage: e.message);
      }
    } catch (e) {
      if (state.localFilePath != null) {
        state = state.copyWith(isLoading: false);
        return;
      }
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> _cacheFileInBackground(int id, String url) async {
    if (kIsWeb) {
      if (mounted) {
        state = state.copyWith(isLoading: false);
      }
      return;
    }
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final localPath = '${appDir.path}/cached_journal_$id.pdf';
      final file = File(localPath);

      if (await file.exists()) {
        await _downloadService.saveDownloadLocation(id.toString(), localPath);
        if (mounted) {
          state = state.copyWith(localFilePath: localPath, isLoading: false);
        }
        return;
      }

      final dio = Dio();
      await dio.download(url, localPath);

      await _downloadService.saveDownloadLocation(id.toString(), localPath);
      if (mounted) {
        state = state.copyWith(localFilePath: localPath, isLoading: false);
      }
    } catch (e) {
      // Échec silencieux du téléchargement de cache en tâche de fond, pour ne pas bloquer.
      if (mounted) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  void _restoreReadingPosition() {
    final lastPage = _storageService.get(
      'read_pos_$journalId',
      defaultValue: 0,
    );
    if (lastPage > 0) {
      state = state.copyWith(currentPage: lastPage);
    }
  }

  Future<void> _checkDownloadStatus() async {
    if (kIsWeb) return;
    final path = await _downloadService.getDownloadLocation(journalId);
    if (path != null) {
      // Vérifier si le fichier existe toujours
      if (File(path).existsSync()) {
        state = state.copyWith(localFilePath: path);
      }
    }
  }

  Future<void> downloadJournal(String url) async {
    state = state.copyWith(isDownloading: true);
    final fileName = 'journal_$journalId.pdf';

    // Initialiser le service de téléchargement si nécessaire
    await _downloadService.initialize();

    final taskId = await _downloadService.downloadJournal(url, fileName);

    if (taskId != null) {
      // Note: Pour une vraie implémentation, on écouterait le port isolate
      // Ici on suppose que le téléchargement va réussir pour simplifier l'UI
      // Dans un cas réel, il faudrait écouter les événements de FlutterDownloader

      // Simulation de délai de téléchargement pour l'UX
      await Future.delayed(const Duration(seconds: 2));

      // On récupère le chemin supposé (FlutterDownloader stocke dans app documents)
      // Ajustement nécessaire selon le DownloadService réel
      // Pour l'instant on force un refresh au prochain démarrage ou on suppose le succès
    }
    state = state.copyWith(isDownloading: false);
  }

  void toggleNightMode() {
    state = state.copyWith(isNightMode: !state.isNightMode);
  }

  @override
  void dispose() {
    // Désactive les protections DRM lors de la fermeture de l'écran.
    _securityService.setSecureMode(false);
    super.dispose();
  }

  /// Notifie le changement de page.
  void onPageChanged(int index) {
    state = state.copyWith(currentPage: index);
    _storageService.set('read_pos_$journalId', index);
  }

  /// Marque le document comme chargé avec le nombre total de pages.
  void onDocumentLoaded(int pages) {
    state = state.copyWith(isLoading: false, totalPages: pages);
  }

  /// Gère les erreurs de chargement du PDF.
  void onReaderError(String message) {
    state = state.copyWith(isLoading: false, errorMessage: message);
  }
}

/// Fournisseur global du [ReaderViewModel], indexé par [journalId].
final readerViewModelProvider =
    StateNotifierProvider.family<ReaderViewModel, ReaderState, String>((
      ref,
      journalId,
    ) {
      final securityService = ref.read(securityServiceProvider);
      final downloadService = ref.read(downloadServiceProvider);
      final storageService = ref.read(storageServiceProvider);
      final publicationService = ref.read(publicationServiceProvider);
      return ReaderViewModel(
        securityService,
        downloadService,
        storageService,
        publicationService,
        journalId,
      );
    });
