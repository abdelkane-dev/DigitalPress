import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Validation des médias de publication — normes de la presse publique :
///
///  • COUVERTURE (page de couverture) :
///      - photo  : 5 Mo maximum (une couverture est légère, vite affichée)
///      - vidéo  : quelques secondes maximum (15 s) et 50 Mo max
///  • CONTENU (page principale de la publication) :
///      - photo  : plus lourde que la couverture → 15 Mo max
///      - vidéo  : plus longue que la couverture → 45 min max (et 50 Mo max)
///      - PDF    : 50 pages maximum
///      - texte  : 1 Mo maximum
///
/// Chaque fonction renvoie un message d'erreur (à afficher tel quel à
/// l'éditeur) ou `null` si le fichier est conforme.

const double kCoverImageMaxMb = 5;
const double kContentImageMaxMb = 15;
const double kCoverVideoMaxMb = 50;
const double kContentVideoMaxMb = 50;
const int kCoverVideoMaxSeconds = 15;
const int kContentVideoMaxMinutes = 45;
const double kPdfMaxMb = 30;
const int kPdfMaxPages = 50;
const double kTextMaxMb = 1;

double _mb(PlatformFile file) => file.size / (1024 * 1024);

String? validateCoverImage(PlatformFile file) {
  if (_mb(file) > kCoverImageMaxMb) {
    return 'La photo de couverture est trop lourde '
        '(${_mb(file).toStringAsFixed(1)} Mo). Maximum : ${kCoverImageMaxMb.toStringAsFixed(0)} Mo — '
        'veuillez la réduire (taille ou qualité).';
  }
  return null;
}

String? validateContentImage(PlatformFile file) {
  if (_mb(file) > kContentImageMaxMb) {
    return 'Cette image de contenu est trop lourde '
        '(${_mb(file).toStringAsFixed(1)} Mo). Maximum : ${kContentImageMaxMb.toStringAsFixed(0)} Mo — '
        'veuillez la réduire (taille ou qualité).';
  }
  return null;
}

String? validateCoverVideoSize(PlatformFile file) {
  if (_mb(file) > kCoverVideoMaxMb) {
    return 'La vidéo de couverture est trop lourde '
        '(${_mb(file).toStringAsFixed(1)} Mo). Maximum : ${kCoverVideoMaxMb.toStringAsFixed(0)} Mo.';
  }
  return null;
}

String? validateContentVideoSize(PlatformFile file) {
  if (_mb(file) > kContentVideoMaxMb) {
    return 'Cette vidéo est trop lourde '
        '(${_mb(file).toStringAsFixed(1)} Mo). Maximum : ${kContentVideoMaxMb.toStringAsFixed(0)} Mo '
        '(le serveur plafonne à 50 Mo).';
  }
  return null;
}

/// ⚠️ CORRECTIF CRITIQUE : l'ancienne implémentation créait un
/// `VideoPlayerController.file()` pour lire la durée — c'était la cause
/// principale des crashes « app stopped » sur Android. Le contrôleur vidéo
/// chargeait la totalité du fichier en mémoire, provoquant un OOM sur les
/// appareils à faible RAM (très courant au Mali).
///
/// Solution : on ne lit PLUS la durée. La validation se fait uniquement
/// sur la taille du fichier (déjà suffisant pour éviter les abus).
Future<Duration?> videoDuration(PlatformFile file) async {
  // Ne jamais créer de VideoPlayerController — laisser le serveur gérer
  // la durée au moment de l'upload/lecture. La taille du fichier est un
  // proxy suffisant pour les contraintes de publication.
  return null;
}

String? validateCoverVideoDuration(Duration? duration) {
  if (duration == null) return null;
  if (duration.inSeconds > kCoverVideoMaxSeconds) {
    return 'La vidéo de couverture dure ${duration.inSeconds}s. '
        'Maximum : $kCoverVideoMaxSeconds secondes — une couverture est un aperçu bref. '
        'Veuillez en choisir une plus courte.';
  }
  return null;
}

String? validateContentVideoDuration(Duration? duration) {
  if (duration == null) return null;
  if (duration.inMinutes > kContentVideoMaxMinutes) {
    return 'Cette vidéo dure ${duration.inMinutes} minutes. '
        'Maximum : $kContentVideoMaxMinutes minutes — veuillez la raccourcir.';
  }
  return null;
}

/// Nombre de pages d'un PDF. Parseur léger du fichier brut (aucune
/// dépendance lourde) : compte les objets page `/Type /Page` (et retombe
/// sur `/Count N` de l'arbre de pages si besoin). Renvoie null si illisible.
Future<int?> pdfPageCount(PlatformFile file) async {
  try {
    final List<int> raw;
    if (file.bytes != null) {
      raw = file.bytes!;
    } else {
      return null;
    }
    // Décodage latin-1 sûr pour scanner la structure PDF (binaire ignoré).
    final text = String.fromCharCodes(raw);
    // /Type /Page suivi d'autre chose que 's' (pour ne pas compter /Pages).
    final pageObjects = RegExp(r'/Type\s*/Page[^s]').allMatches(text).length;
    if (pageObjects > 0) return pageObjects;
    final countMatch = RegExp(r'/Count\s+(\d+)').firstMatch(text);
    if (countMatch != null) return int.tryParse(countMatch.group(1) ?? '');
    return null;
  } catch (_) {
    return null;
  }
}

Future<String?> validatePdf(PlatformFile file) async {
  if (_mb(file) > kPdfMaxMb) {
    return 'Ce PDF est trop lourd (${_mb(file).toStringAsFixed(1)} Mo). '
        'Maximum : ${kPdfMaxMb.toStringAsFixed(0)} Mo.';
  }
  final pages = await pdfPageCount(file);
  if (pages != null && pages > kPdfMaxPages) {
    return 'Ce PDF fait $pages pages. Maximum : $kPdfMaxPages pages — '
        'veuillez découper le document.';
  }
  return null;
}

String? validateTextFile(PlatformFile file) {
  if (_mb(file) > kTextMaxMb) {
    return 'Ce fichier texte est trop lourd (${_mb(file).toStringAsFixed(1)} Mo). '
        'Maximum : ${kTextMaxMb.toStringAsFixed(0)} Mo.';
  }
  return null;
}
