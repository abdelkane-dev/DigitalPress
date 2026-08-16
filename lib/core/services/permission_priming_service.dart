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
  static const _primedKey = 'permissions_primed_v1';
  final StorageService _storage;

  PermissionPrimingService(this._storage);

  bool get alreadyPrimed => _storage.get(_primedKey, defaultValue: false) as bool;

  Future<void> primeIfNeeded() async {
    if (alreadyPrimed || kIsWeb) {
      return;
    }

    // Notifications d'abord (le plus important pour l'usage courant :
    // messages, paiements, vérification éditeur...).
    await Permission.notification.request();

    // Photos/vidéos et caméra : utiles dès la première utilisation (avatar,
    // création d'article pour un éditeur, même si tous les comptes ne s'en
    // serviront pas — mieux vaut le demander une fois pour toutes plutôt
    // que d'interrompre l'utilisateur au milieu d'une action plus tard).
    if (PlatformHelper.isAndroid) {
      await Permission.photos.request();
      await Permission.videos.request();
    } else {
      // iOS : une seule permission couvre photos ET vidéos de la galerie.
      await Permission.photos.request();
    }
    await Permission.camera.request();

    // Marqué comme fait quelle que soit la réponse (accordé ou refusé) :
    // jamais redemandé de force, réglable plus tard dans les paramètres.
    await _storage.set(_primedKey, true);
  }
}

final permissionPrimingServiceProvider = Provider<PermissionPrimingService>((ref) {
  return PermissionPrimingService(ref.watch(storageServiceProvider));
});
