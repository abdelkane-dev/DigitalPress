/// Transforme une erreur technique brute (DioException, SocketException,
/// texte serveur…) en un message COURT et compréhensible pour l'utilisateur.
/// On est en 2026 : plus jamais de long texte technique à l'écran.
String friendlyError(Object? error) {
  if (error == null) return 'Une erreur est survenue. Réessayez.';
  final s = error.toString();

  // Catégories réseau / serveur → messages humains immédiats.
  final lower = s.toLowerCase();
  if (lower.contains('socketexception') ||
      lower.contains('connection refused') ||
      lower.contains('connectionerror') ||
      lower.contains('connection closed') ||
      lower.contains('timeout') ||
      lower.contains('handshake')) {
    return 'Connexion impossible. Vérifiez votre réseau.';
  }
  if (lower.contains('401') || lower.contains('unauthorized')) {
    return 'Session expirée. Reconnectez-vous.';
  }
  if (lower.contains('403') || lower.contains('forbidden')) {
    return 'Accès refusé pour cette action.';
  }
  if (lower.contains('404') || lower.contains('not found')) {
    return 'Élément introuvable.';
  }
  if (lower.contains('500') ||
      lower.contains('internal server') ||
      lower.contains('bad gateway') ||
      lower.contains('unavailable')) {
    return 'Le serveur rencontre un problème. Réessayez dans un instant.';
  }
  if (lower.contains('dioexception')) {
    return 'Erreur réseau. Réessayez.';
  }

  // Sinon : on nettoie le préfixe technique (DioException…, Exception:) et
  // on tronque à 120 caractères — un message court, jamais un pavé.
  var cleaned = s
      .replaceAll(RegExp(r'DioException\s*\[[^\]]*\]:?\s*'), '')
      .replaceAll(RegExp(r'Exception:\s*'), '')
      .replaceAll(RegExp(r'^Exception\s*'), '')
      .trim();
  // On retire aussi les URL complètes (bruit technique inutile).
  cleaned = cleaned.replaceAll(RegExp(r'https?://\S+'), '');
  cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (cleaned.isEmpty) return 'Une erreur est survenue. Réessayez.';
  if (cleaned.length > 120) {
    cleaned = '${cleaned.substring(0, 117)}…';
  }
  return cleaned;
}
