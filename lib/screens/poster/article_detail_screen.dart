import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../config/api_config.dart';
import '../../widgets/short_video_player.dart';
import '../reader/reader_screen.dart' show FullScreenPdfViewer;
import 'package:cached_network_image/cached_network_image.dart';

/// Écran de détail d'un article (espace éditeur).
/// Rend images, vidéos et PDFs exactement comme dans le ReaderScreen.
class ArticleDetailScreen extends StatelessWidget {
  final dynamic publication; // Publication model

  const ArticleDetailScreen({super.key, required this.publication});

  String _sanitize(String url) => ApiConfig.sanitizeUrl(url);

  @override
  Widget build(BuildContext context) {
    final contentText = (publication.content as String).trim().isNotEmpty
        ? publication.content as String
        : publication.description as String;

    final lines = contentText.split('\n');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails de l\'article'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Cover image
          if ((publication.coverImage as String).isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: CachedNetworkImage(
                imageUrl: _sanitize(publication.coverImage as String),
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  height: 220,
                  width: double.infinity,
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          const SizedBox(height: 16),

          // Title
          Text(
            publication.title as String,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0A2647),
            ),
          ),
          const SizedBox(height: 10),

          // Description/summary
          Text(
            publication.description as String,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),

          // Rich content rendering
          ...lines.map((line) => _buildLine(context, line)),
        ],
      ),
    );
  }

  Widget _buildLine(BuildContext context, String line) {
    final trimmed = line.trim();

    if (trimmed.isEmpty) return const SizedBox(height: 10);

    // Headings
    if (trimmed.startsWith('# ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(
          trimmed.substring(2),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0A2647),
          ),
        ),
      );
    }
    if (trimmed.startsWith('## ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(
          trimmed.substring(3),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0A2647)),
        ),
      );
    }

    // Bullet list
    if (trimmed.startsWith('- ')) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('• ', style: TextStyle(fontSize: 16)),
            Expanded(
              child: Text(trimmed.substring(2),
                  style: const TextStyle(fontSize: 16, height: 1.5)),
            ),
          ],
        ),
      );
    }

    // Blockquote
    if (trimmed.startsWith('> ')) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: Colors.blue.shade400, width: 4)),
        ),
        child: Text(trimmed.substring(2),
            style: TextStyle(
                fontSize: 15, height: 1.5, fontStyle: FontStyle.italic, color: Colors.grey.shade800)),
      );
    }

    // Divider
    if (trimmed == '---') {
      return const Padding(
          padding: EdgeInsets.symmetric(vertical: 12), child: Divider());
    }

    // ── 1. IMAGE ───────────────────────────────────────────────
    final imageMatch = RegExp(r'^!\[(.*?)\]\((.*?)\)$').firstMatch(trimmed);
    if (imageMatch != null || (trimmed.startsWith('![') && trimmed.endsWith(')'))) {
      final rawUrl = imageMatch?.group(2) ??
          RegExp(r'\((.*?)\)').firstMatch(trimmed)?.group(1) ?? '';
      final imageUrl = _sanitize(rawUrl);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: imageUrl.startsWith('http')
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: double.infinity,
                  fit: BoxFit.fitWidth,
                  placeholder: (_, __) => Container(
                    height: 150,
                    width: double.infinity,
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  errorWidget: (_, __, ___) =>
                      _mediaMissing('Image non disponible'))
              : Image.file(File(imageUrl),
                  width: double.infinity,
                  fit: BoxFit.fitWidth,
                  errorBuilder: (_, __, ___) =>
                      _mediaMissing('Image locale non disponible')),
        ),
      );
    }

    final simpleLinkMatch = RegExp(r'\[(.*?)\]\((.*?)\)').firstMatch(trimmed);

    // ── 2. VIDEO ───────────────────────────────────────────────
    final isVideoPrefix = trimmed.contains('🎬') || trimmed.contains('🎥');
    final isVideoExtension =
        RegExp(r'\.(mp4|avi|mov|mkv|webm)(\?|$)').hasMatch(trimmed);
    if (simpleLinkMatch != null && (isVideoPrefix || isVideoExtension)) {
      final videoTitle = simpleLinkMatch.group(1) ?? 'Vidéo';
      final videoUrl = _sanitize(simpleLinkMatch.group(2) ?? '');
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🎬 $videoTitle',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 220,
                width: double.infinity,
                child: ShortVideoPlayer(videoUrl: videoUrl, title: videoTitle),
              ),
            ),
          ],
        ),
      );
    }

    // ── 3. PDF ────────────────────────────────────────────────
    final isPdfPrefix =
        trimmed.contains('📄') || trimmed.contains('📕') || trimmed.contains('PDF');
    final isPdfExtension = RegExp(r'\.(pdf)(\?|$)').hasMatch(trimmed);
    if (simpleLinkMatch != null && (isPdfPrefix || isPdfExtension)) {
      final pdfTitle = simpleLinkMatch.group(1) ?? 'Document PDF';
      final pdfUrl = _sanitize(simpleLinkMatch.group(2) ?? '');
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Container(
          height: 550, // Toutes les pages défilables horizontalement
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
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
                    debugPrint('Detail PDF load error: ${details.description}');
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
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FullScreenPdfViewer(
                            pdfUrl: pdfUrl,
                            title: (publication.title as String).isNotEmpty ? (publication.title as String) : pdfTitle,
                          ),
                        ),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.fullscreen_rounded,
                            color: Colors.white, size: 28),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── Texte ordinaire ───────────────────────────────────────
    final cleaned = trimmed
        .replaceAll(RegExp(r'\*\*'), '')
        .replaceAll(RegExp(r'__'), '')
        .replaceAll(RegExp(r'\[(.*?)\]\((.*?)\)'), r'$1');

    if (cleaned.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(cleaned, style: const TextStyle(fontSize: 16, height: 1.5)),
    );
  }

  Widget _mediaMissing(String message) => Container(
        padding: const EdgeInsets.all(12),
        color: Colors.grey.shade200,
        child: Text(message),
      );
}
