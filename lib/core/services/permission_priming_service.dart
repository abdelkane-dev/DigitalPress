import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../storage/storage_service.dart';
import '../utils/platform_helper.dart';

/// Demande groupée des permissions de l'appareil (photos/vidéos, caméra,
/// notifications) une seule fois, juste après la toute première connexion
/// réussie — jamais répétée aux connexions suivantes, et jamais spécifique
/// à un rôle (lecteur/éditeur/admin voient exactement le même prompt une
/// seule fois par appareil, pas de conflit entre comptes).
///
/// L'indicateur est stocké dans Hive (StorageService), qui survit à une
/// déconnexion/reconnexion — seule une désinstallation de l'app le
/// réinitialise, ce qui est le comportement attendu.
class PermissionPrimingService {
  static const _primedKey = 'permissions_primed_v2';
  final StorageService _storage;

  PermissionPrimingService(this._storage);

  bool get alreadyPrimed => _storage.get(_primedKey, defaultValue: false) as bool;

  /// Vérifie d'abord l'état réel des autorisations auprès du système.
  /// Si l'appareil confirme que les accès (photos, vidéos, caméra, notifications)
  /// sont déjà accordés, aucune demande n'est émise et l'état est mémorisé.
  /// Si une autorisation manque, elle est demandée naturellement et silencieusement.
  Future<void> primeIfNeeded() async {
    if (kIsWeb) return;

    try {
      // 1. Vérification des notifications
      final notifStatus = await Permission.notification.status;
      if (!notifStatus.isGranted && !notifStatus.isPermanentlyDenied && !notifStatus.isRestricted) {
        await Permission.notification.request();
      }

      // 2. Vérification Photos / Vidéos
      if (PlatformHelper.isAndroid) {
        final photosStatus = await Permission.photos.status;
        if (!photosStatus.isGranted && !photosStatus.isPermanentlyDenied && !photosStatus.isRestricted) {
          await Permission.photos.request();
        }

        final videosStatus = await Permission.videos.status;
        if (!videosStatus.isGranted && !videosStatus.isPermanentlyDenied && !videosStatus.isRestricted) {
          await Permission.videos.request();
        }
      } else if (PlatformHelper.isIOS) {
        final photosStatus = await Permission.photos.status;
        if (!photosStatus.isGranted && !photosStatus.isLimited && !photosStatus.isPermanentlyDenied) {
          await Permission.photos.request();
        }
      }

      // 3. Vérification Caméra
      final cameraStatus = await Permission.camera.status;
      if (!cameraStatus.isGranted && !cameraStatus.isPermanentlyDenied && !cameraStatus.isRestricted) {
        await Permission.camera.request();
      }

      // Mémoriser la confirmation pour éviter les vérifications répétitives
      await _storage.set(_primedKey, true);
    } catch (_) {
      // Silencieux : aucune interruption pour l'utilisateur en cas d'erreur de plugin
    }
  }
}

final permissionPrimingServiceProvider = Provider<PermissionPrimingService>((ref) {
  return PermissionPrimingService(ref.watch(storageServiceProvider));
});
