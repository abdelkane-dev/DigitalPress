import 'dart:io';
import 'package:digital_press/model/reader_view_model.dart';
import 'package:digital_press/widgets/watermark_overlay.dart';
import 'package:digital_press/widgets/subscribe_or_buy_sheet.dart';
import 'package:digital_press/core/services/publication_service.dart';
import 'package:digital_press/core/services/auth_service.dart';
import 'package:digital_press/model/publication.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:digital_press/config/api_config.dart';
import 'package:go_router/go_router.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../core/services/preview_service.dart';
import '../../core/services/security_service.dart';
import '../../widgets/short_video_player.dart';

String sanitizeMediaUrl(String url) {
  if (url.isEmpty) return url;
  if (url.contains('localhost:8000') || url.contains('127.0.0.1:8000')) {
    final apiBase = ApiConfig.baseUrl; // ex: http://10.0.2.2:8000/api/
    final uri = Uri.parse(apiBase);
    final actualHost = '${uri.scheme}://${uri.host}:${uri.port}';
    return url
        .replaceAll('http://localhost:8000', actualHost)
        .replaceAll('http://127.0.0.1:8000', actualHost);
  }
  return url;
}

/// Écran principal de lecture des journaux et magazines.
/// Intègre :
/// - Protection DRM (FLAG_SECURE = interdiction des captures d'écran)
/// - Restriction de lecture aux 3 premières pages pour les non-abonnés
/// - Mode nuit
/// - Téléchargement & lecture hors ligne
class ReaderScreen extends ConsumerStatefulWidget {
  final String journalId;
  final bool isSubscribed;

  const ReaderScreen({
    super.key,
    required this.journalId,
    this.isSubscribed = false,
  });

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  late PdfViewerController _pdfViewerController;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    // Activer FLAG_SECURE dès l'ouverture du lecteur
    ref.read(securityServiceProvider).setSecureMode(true);
  }

  @override
  void dispose() {
    // Désactiver FLAG_SECURE quand on quitte le lecteur
    ref.read(securityServiceProvider).setSecureMode(false);
    _pdfViewerController.dispose();
    super.dispose();
  }

  void _showVideoDialog(BuildContext context, String videoUrl, String title) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
            ShortVideoPlayer(videoUrl: videoUrl, title: title),
          ],
        ),
      ),
    );
  }

  void _onPageChanged(PdfPageChangedDetails details, bool isSubscribed,
      ReaderViewModel viewModel) {
    final newPage = details.newPageNumber;
    viewModel.onPageChanged(newPage);

    // Blocage si non-abonné et dépassement de la page 3
    if (!isSubscribed && newPage > PreviewService.maxPreviewPages) {
      // Forcer le retour à la dernière page autorisée
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _pdfViewerController.jumpToPage(PreviewService.maxPreviewPages);
          _showSubscribeSheet();
        }
      });
    }
  }

  void _showSubscribeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(28),
        decoration: const BoxDecoration(
          color: Color(0xFF0A2647),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline_rounded,
                color: Colors.white, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Contenu réservé aux abonnés',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Vous avez atteint la limite de lecture gratuite (3 pages).\n'
              'Abonnez-vous ou achetez ce numéro pour accéder à l\'intégralité du contenu.',
              style:
                  TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context); // Ferme le BottomSheet actuel

                  // Récupérer la publication et afficher la sélection d'achat/abonnement
                  ref
                      .read(
                          publicationDetailProvider(int.parse(widget.journalId))
                              .future)
                      .then((pub) {
                    if (mounted) {
                      showSubscribeOrBuySelection(context, ref, pub);
                    }
                  }).catchError((err) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erreur : $err')),
                      );
                    }
                  });
                },
                icon: const Icon(Icons.star_rounded),
                label: const Text("Débloquer le contenu"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2C74B3),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(readerViewModelProvider(widget.journalId));
    final viewModel =
        ref.read(readerViewModelProvider(widget.journalId).notifier);
    final pubDetailAsync =
        ref.watch(publicationDetailProvider(int.parse(widget.journalId)));
    final isArticle = pubDetailAsync.valueOrNull?.pubType == 'article';
    final showLoading = state.isLoading && !isArticle;

    return Scaffold(
      backgroundColor:
          state.isNightMode ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: pubDetailAsync.when(
          data: (pub) => Text(pub.title),
          loading: () => Text('Journal #${widget.journalId}'),
          error: (_, __) => Text('Journal #${widget.journalId}'),
        ),
        actions: [
          // Badge "accès limité" pour les non-abonnés
          if (!widget.isSubscribed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      '3 pages gratuites',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          // Bouton pour regarder la courte vidéo de présentation si disponible
          pubDetailAsync.when(
            data: (pub) {
              if (pub.videoUrl.isNotEmpty) {
                return IconButton(
                  icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.redAccent),
                  tooltip: 'Regarder la présentation vidéo',
                  onPressed: () => _showVideoDialog(context, pub.videoUrl, pub.title),
                );
              }
              return const SizedBox.shrink();
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          // Le bouton de téléchargement devient un bouton d'accès à la
          // conversation de l'article (commentaires + avis), accessible dès
          // que l'utilisateur est en train de lire l'article.
          IconButton(
            icon: const Icon(Icons.forum_rounded),
            tooltip: 'Voir la conversation',
            onPressed: () {
              final pubId = int.tryParse(widget.journalId);
              if (pubId != null) {
                context.push('/article/$pubId?scrollToComments=true');
              }
            },
          ),
          IconButton(
            icon: Icon(
              state.isNightMode
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
            ),
            onPressed: viewModel.toggleNightMode,
          ),
        ],
      ),
      body: Stack(
        children: [
          if (state.accessDenied)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_outline_rounded,
                        size: 56, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'Abonnement requis pour lire ce document',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _showSubscribeSheet,
                      icon: const Icon(Icons.star_rounded),
                      label: const Text('Voir les options d\'abonnement'),
                    ),
                  ],
                ),
              ),
            )
          else
            pubDetailAsync.when(
              data: (pub) {
                if (pub.pubType == 'article') {
                  if (pub.prix > 0 && !pub.isSubscribed) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.lock_outline_rounded,
                                size: 56, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text(
                              'Cet article est payant',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Vous devez acheter ou vous abonner pour lire le contenu complet.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _showSubscribeSheet,
                              icon: const Icon(Icons.star_rounded),
                              label: const Text('Voir les options'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return _buildArticleContentView(pub, state.isNightMode);
                }
                return ColorFiltered(
                  colorFilter: state.isNightMode
                      ? const ColorFilter.matrix([
                          -1,
                          0,
                          0,
                          0,
                          255,
                          0,
                          -1,
                          0,
                          0,
                          255,
                          0,
                          0,
                          -1,
                          0,
                          255,
                          0,
                          0,
                          0,
                          1,
                          0,
                        ])
                      : const ColorFilter.mode(
                          Colors.transparent,
                          BlendMode.multiply,
                        ),
                  child: state.localFilePath != null
                      ? SfPdfViewer.file(
                          File(state.localFilePath!),
                          controller: _pdfViewerController,
                          onDocumentLoaded: (details) {
                            if (mounted) {
                              viewModel
                                  .onDocumentLoaded(details.document.pages.count);
                              if (state.currentPage > 1) {
                                _pdfViewerController
                                    .jumpToPage(state.currentPage);
                              }
                            }
                          },
                          onDocumentLoadFailed: (details) {
                            if (mounted) {
                              viewModel.onReaderError(
                                'Impossible de charger le fichier local: ${details.description}',
                              );
                            }
                          },
                          onPageChanged: (details) {
                            if (mounted) {
                              _onPageChanged(
                                  details, widget.isSubscribed, viewModel);
                            }
                          },
                        )
                      : (state.fileUrl == null
                          ? const SizedBox.shrink()
                          : SfPdfViewer.network(
                              sanitizeMediaUrl(state.fileUrl!),
                              controller: _pdfViewerController,
                              onDocumentLoaded: (details) {
                                if (mounted) {
                                  viewModel.onDocumentLoaded(
                                      details.document.pages.count);
                                  if (state.currentPage > 1) {
                                    _pdfViewerController
                                        .jumpToPage(state.currentPage);
                                  }
                                }
                              },
                              onDocumentLoadFailed: (details) {
                                if (mounted) {
                                  viewModel.onReaderError(
                                    'Impossible de charger le document: ${details.description}',
                                  );
                                }
                              },
                              onPageChanged: (details) {
                                if (mounted) {
                                  _onPageChanged(
                                      details, widget.isSubscribed, viewModel);
                                }
                              },
                            )),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Text(
                  'Erreur de chargement: $err',
                  style: TextStyle(
                      color:
                          state.isNightMode ? Colors.white70 : Colors.black87),
                ),
              ),
            ),


          // Filigrane d'identité réel (dissuasif pour les photos de l'écran) :
          // affiche l'identité du lecteur effectivement connecté, et non une
          // valeur factice, afin que la dissuasion anti-piratage ait un sens.
          if (!state.accessDenied)
            Consumer(
              builder: (context, ref, _) {
                final currentUser = ref.watch(authStateProvider).valueOrNull;
                return WatermarkOverlay(
                  userId: currentUser?.id ?? '—',
                  email: currentUser?.email ?? '',
                );
              },
            ),

          // Barre de progression du document visible pour les non-abonnés
          if (!widget.isSubscribed && state.totalPages > 0 && !isArticle)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: Colors.black.withValues(alpha: 0.75),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(
                      value: PreviewService.maxPreviewPages / state.totalPages,
                      backgroundColor: Colors.white24,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.amber),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Accès gratuit : ${PreviewService.maxPreviewPages} / ${state.totalPages} pages',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

          if (showLoading) const Center(child: CircularProgressIndicator()),

          if (state.errorMessage != null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(state.errorMessage!),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildArticleContentView(Publication publication, bool isNightMode) {
    final themeBgColor =
        isNightMode ? const Color(0xFF121212) : const Color(0xFFF8FAFC);
    final themeTextColor =
        isNightMode ? Colors.white70 : const Color(0xFF1E293B);
    final themeHeaderColor =
        isNightMode ? Colors.white : const Color(0xFF0A2647);

    final widgets = <Widget>[];

    // Title
    widgets.add(Text(
      publication.title,
      style: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w900,
        color: themeHeaderColor,
      ),
    ));
    widgets.add(const SizedBox(height: 8));

    // Metadata row
    widgets.add(Row(
      children: [
        if (publication.categoryName != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF2C74B3).withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              publication.categoryName!,
              style: const TextStyle(
                color: Color(0xFF2C74B3),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        TextButton(
          onPressed: publication.publisherId > 0
              ? () => context.push('/publisher/${publication.publisherId}')
              : null,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'Par ${publication.publisherName}',
            style: TextStyle(
              color: const Color(0xFF2C74B3),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    ));
    widgets.add(const SizedBox(height: 16));

    if (publication.videoUrl.isNotEmpty) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: ShortVideoPlayer(
          videoUrl: sanitizeMediaUrl(publication.videoUrl),
          title: "Présentation vidéo",
        ),
      ));
    } else if (publication.coverImage.isNotEmpty) {
      widgets.add(ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          sanitizeMediaUrl(publication.coverImage),
          width: double.infinity,
          height: 200,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        ),
      ));
      widgets.add(const SizedBox(height: 20));
    }

    // Parse description/summary if any as an intro paragraph
    if (publication.description.isNotEmpty) {
      widgets.add(Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              isNightMode ? const Color(0xFF1E1E1E) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isNightMode ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
        child: Text(
          publication.description,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: themeTextColor,
            height: 1.5,
          ),
        ),
      ));
      widgets.add(const SizedBox(height: 20));
    }

    // Parse main content
    final blocks = publication.content.split(RegExp(r'\n\s*\n'));
    for (var block in blocks) {
      block = block.trim();
      if (block.isEmpty) continue;

      if (block == '---') {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Divider(
              color: isNightMode ? Colors.white12 : Colors.grey.shade300),
        ));
        continue;
      }

      if (block.startsWith('# ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            block.substring(2).replaceAll('**', '').replaceAll('__', ''),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: themeHeaderColor,
            ),
          ),
        ));
        continue;
      }
      if (block.startsWith('## ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(
            block.substring(3).replaceAll('**', '').replaceAll('__', ''),
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: themeHeaderColor,
            ),
          ),
        ));
        continue;
      }
      if (block.startsWith('### ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text(
            block.substring(4).replaceAll('**', '').replaceAll('__', ''),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: themeHeaderColor,
            ),
          ),
        ));
        continue;
      }

      if (block.startsWith('> ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.only(left: 14, top: 6, bottom: 6),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: Color(0xFF2C74B3), width: 4),
              ),
            ),
            child: Text(
              block.substring(2).replaceAll('**', '').replaceAll('__', ''),
              style: TextStyle(
                fontSize: 16,
                fontStyle: FontStyle.italic,
                color: themeTextColor.withValues(alpha: 0.85),
                height: 1.5,
              ),
            ),
          ),
        ));
        continue;
      }

      // Pour les paragraphes ordinaires, on sépare par lignes afin d'intercepter les fichiers médias n'importe où
      final lines = block.split('\n');
      String textBuffer = '';

      void flushTextBuffer() {
        if (textBuffer.trim().isNotEmpty) {
          var cleanedText = textBuffer.trim()
              .replaceAll(RegExp(r'\*\*'), '')
              .replaceAll(RegExp(r'__'), '');

          // Traiter les liens ordinaires s'il y en a dans le texte
          final linkMatches = RegExp(r'\[(.*?)\]\((.*?)\)').allMatches(cleanedText);
          if (linkMatches.isNotEmpty) {
            cleanedText = cleanedText.replaceAll(RegExp(r'\[(.*?)\]\((.*?)\)'), r'$1');
          }

          widgets.add(Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              cleanedText,
              style: TextStyle(
                fontSize: 16,
                color: themeTextColor,
                height: 1.6,
              ),
            ),
          ));
          textBuffer = '';
        }
      }

      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty) continue;

        // 1. Image Match : ![alt](url)
        final imageMatch = RegExp(r'^!\[(.*?)\]\((.*?)\)$').firstMatch(line);
        final simpleLinkMatch = RegExp(r'\[(.*?)\]\((.*?)\)').firstMatch(line);

        if (imageMatch != null || (line.startsWith('![') && line.endsWith(')'))) {
          flushTextBuffer();
          final imageUrl = sanitizeMediaUrl(imageMatch?.group(2) ?? RegExp(r'\((.*?)\)').firstMatch(line)?.group(1) ?? '');
          widgets.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageUrl.startsWith('http')
                  ? Image.network(
                      imageUrl,
                      width: double.infinity,
                      fit: BoxFit.fitWidth,
                      errorBuilder: (context, error, stackTrace) => Container(
                        padding: const EdgeInsets.all(12),
                        color: Colors.grey.shade200,
                        child: const Text('Image non disponible'),
                      ),
                    )
                  : Image.file(
                      File(imageUrl),
                      width: double.infinity,
                      fit: BoxFit.fitWidth,
                      errorBuilder: (context, error, stackTrace) => Container(
                        padding: const EdgeInsets.all(12),
                        color: Colors.grey.shade200,
                        child: const Text('Image locale non disponible'),
                      ),
                    ),
            ),
          ));
          continue;
        }

        // 2. Video Match : 🎬 [title](url) ou lien finissant par une extension vidéo
        final isVideoPrefix = line.contains('🎬') || line.contains('🎥');
        final isVideoExtension = RegExp(r'\.(mp4|avi|mov|mkv|webm)(\?|$)').hasMatch(line);
        
        if (simpleLinkMatch != null && (isVideoPrefix || isVideoExtension)) {
          flushTextBuffer();
          final videoTitle = simpleLinkMatch.group(1) ?? 'Vidéo';
          final videoUrl = sanitizeMediaUrl(simpleLinkMatch.group(2) ?? '');
          widgets.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🎬 $videoTitle',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: themeHeaderColor,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 220,
                    width: double.infinity,
                    child: ShortVideoPlayer(
                      videoUrl: videoUrl,
                      title: videoTitle,
                    ),
                  ),
                ),
              ],
            ),
          ));
          continue;
        }

        // 3. PDF Match : 📄 [title](url) or 📕 [title](url) or lien finissant par .pdf
        final isPdfPrefix = line.contains('📄') || line.contains('📕') || line.contains('PDF');
        final isPdfExtension = RegExp(r'\.(pdf)(\?|$)').hasMatch(line);

        if (simpleLinkMatch != null && (isPdfPrefix || isPdfExtension)) {
          flushTextBuffer();
          final pdfTitle = simpleLinkMatch.group(1) ?? 'Document PDF';
          final pdfUrl = sanitizeMediaUrl(simpleLinkMatch.group(2) ?? '');
          widgets.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              height: 550, // Hauteur augmentée pour une meilleure lisibilité
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isNightMode ? Colors.white24 : Colors.grey.shade300,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    SfPdfViewer.network(
                      pdfUrl,
                      scrollDirection: PdfScrollDirection.horizontal,
                      pageLayoutMode: PdfPageLayoutMode.single,
                      enableDoubleTapZooming: true,
                      onDocumentLoadFailed: (details) {
                        debugPrint('Failed to load inline PDF: ${details.description}');
                      },
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FullScreenPdfViewer(
                                  pdfUrl: pdfUrl,
                                  title: publication.title.isNotEmpty ? publication.title : pdfTitle,
                                ),
                              ),
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(
                              Icons.fullscreen_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ));
          continue;
        }

        // Si ce n'est pas un média reconnu, on accumule la ligne dans le tampon de texte
        textBuffer += (textBuffer.isEmpty ? '' : '\n') + line;
      }
      flushTextBuffer();
    }

    return Container(
      color: themeBgColor,
      width: double.infinity,
      height: double.infinity,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: widgets,
        ),
      ),
    );
  }
}

class FullScreenPdfViewer extends StatelessWidget {
  final String pdfUrl;
  final String title;

  const FullScreenPdfViewer({
    super.key,
    required this.pdfUrl,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title.isNotEmpty ? title : 'Document PDF'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SfPdfViewer.network(
        pdfUrl,
        enableDoubleTapZooming: true,
        onDocumentLoadFailed: (details) {
          debugPrint('Failed to load fullscreen PDF: ${details.description}');
        },
      ),
    );
  }
}

