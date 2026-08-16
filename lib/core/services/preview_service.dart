import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fournisseur pour le service de gestion des aperçus gratuits.
final previewServiceProvider = Provider<PreviewService>((ref) {
  return PreviewService();
});

/// Service définissant les règles de lecture limitée pour les non-abonnés.
class PreviewService {
  /// Nombre maximum de pages accessibles gratuitement.
  static const int maxPreviewPages = 3;

  /// Vérifie si l'utilisateur peut accéder à une page spécifique.
  /// [pageIndex] : l'index de la page demandée (commence à 0).
  /// [isSubscribed] : vrai si l'utilisateur possède l'accès complet.
  bool canAccessPage(int pageIndex, {required bool isSubscribed}) {
    // Les abonnés ont accès à tout.
    if (isSubscribed) return true;

    // Les non-abonnés sont restreints aux premières pages.
    return pageIndex < maxPreviewPages;
  }

  /// Retourne le nombre de pages autorisées en mode aperçu.
  int get previewPageCount => maxPreviewPages;
}
