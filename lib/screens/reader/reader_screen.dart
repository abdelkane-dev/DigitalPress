import 'dart:io';
import 'package:digital_press/model/reader_view_model.dart';
import 'package:digital_press/widgets/watermark_overlay.dart';
import 'package:digital_press/widgets/subscribe_or_buy_sheet.dart';
import 'package:digital_press/core/services/publication_service.dart';
import 'package:digital_press/core/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../core/services/preview_service.dart';
import '../../core/services/security_service.dart';

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

  void _onPageChanged(PdfPageChangedDetails details, bool isSubscribed, ReaderViewModel viewModel) {
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
            const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 48),
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
              style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context); // Ferme le BottomSheet actuel
                  
                  // Récupérer la publication et afficher la sélection d'achat/abonnement
                  ref.read(publicationDetailProvider(int.parse(widget.journalId)).future).then((pub) {
                    if (mounted) {
                      showSubscribeOrBuySelection(context, pub);
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    final viewModel = ref.read(readerViewModelProvider(widget.journalId).notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text('Journal #${widget.journalId}'),
        actions: [
          // Badge "accès limité" pour les non-abonnés
          if (!widget.isSubscribed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          if (state.localFilePath == null)
            IconButton(
              icon: state.isDownloading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.download_rounded),
              tooltip: 'Télécharger',
              onPressed: widget.isSubscribed
                  ? (state.isDownloading || state.fileUrl == null
                      ? null
                      : () => viewModel.downloadJournal(state.fileUrl!))
                  : () => _showSubscribeSheet(),
            ),
          IconButton(
            icon: Icon(
              state.isNightMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
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
                    const Icon(Icons.lock_outline_rounded, size: 56, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'Abonnement requis pour lire ce document',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
            ColorFiltered(
              colorFilter: state.isNightMode
                  ? const ColorFilter.matrix([
                      -1, 0,  0, 0, 255,
                       0, -1, 0, 0, 255,
                       0, 0, -1, 0, 255,
                       0, 0,  0, 1, 0,
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
                        viewModel.onDocumentLoaded(details.document.pages.count);
                        if (state.currentPage > 1) {
                          _pdfViewerController.jumpToPage(state.currentPage);
                        }
                      },
                      onDocumentLoadFailed: (details) {
                        viewModel.onReaderError(
                          'Impossible de charger le fichier local: ${details.description}',
                        );
                      },
                      onPageChanged: (details) =>
                          _onPageChanged(details, widget.isSubscribed, viewModel),
                    )
                  : (state.fileUrl == null
                      ? const SizedBox.shrink()
                      : SfPdfViewer.network(
                          state.fileUrl!,
                          controller: _pdfViewerController,
                          onDocumentLoaded: (details) {
                            viewModel.onDocumentLoaded(details.document.pages.count);
                            if (state.currentPage > 1) {
                              _pdfViewerController.jumpToPage(state.currentPage);
                            }
                          },
                          onDocumentLoadFailed: (details) {
                            viewModel.onReaderError(
                              'Impossible de charger le document: ${details.description}',
                            );
                          },
                          onPageChanged: (details) =>
                              _onPageChanged(details, widget.isSubscribed, viewModel),
                        )),
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
          if (!widget.isSubscribed && state.totalPages > 0)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: Colors.black.withValues(alpha: 0.75),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(
                      value: PreviewService.maxPreviewPages / state.totalPages,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Accès gratuit : ${PreviewService.maxPreviewPages} / ${state.totalPages} pages',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

          if (state.isLoading) const Center(child: CircularProgressIndicator()),

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
}
