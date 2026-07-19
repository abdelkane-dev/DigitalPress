import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../config/api_config.dart';
import '../../widgets/short_video_player.dart';
import '../reader/reader_screen.dart' show FullScreenPdfViewer;

/// Aperçu fidèle de l'article — images, vidéos et PDFs sont rendus
/// exactement comme dans l'écran de lecture final (ReaderScreen).
class ArticlePreviewScreen extends StatelessWidget {
  final String title;
  final String category;
  final String summary;
  final String content;
  final String? coverImagePath;

  const ArticlePreviewScreen({
    super.key,
    required this.title,
    required this.category,
    required this.summary,
    required this.content,
    this.coverImagePath,
  });

  String _sanitize(String url) => ApiConfig.sanitizeUrl(url);

  @override
  Widget build(BuildContext context) {
    final lines = content.split('\n');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aperçu de l\'article'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Cover image
          if (coverImagePath != null && coverImagePath!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.file(
                File(coverImagePath!),
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          if (coverImagePath != null && coverImagePath!.isNotEmpty)
            const SizedBox(height: 16),

          // Category chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              category,
              style: TextStyle(
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),

          // Summary
          Text(
            summary,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          // Content lines rendered as rich widgets
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
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      );
    }
    if (trimmed.startsWith('## ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(
          trimmed.substring(3),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      );
    }
    if (trimmed.startsWith('### ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: Text(
          trimmed.substring(4),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
              child: Text(
                trimmed.substring(2),
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
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
        child: Text(
          trimmed.substring(2),
          style: TextStyle(
            fontSize: 15,
            height: 1.5,
            fontStyle: FontStyle.italic,
            color: Colors.grey.shade800,
          ),
        ),
      );
    }

    // Divider
    if (trimmed == '---') {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Divider(),
      );
    }

    // ── 1. IMAGE  ────────────────────────────────────────────────
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
              ? Image.network(
                  imageUrl,
                  width: double.infinity,
                  fit: BoxFit.fitWidth,
                  errorBuilder: (_, __, ___) => _mediaMissing('Image non disponible'),
                )
              : Image.file(
                  File(imageUrl),
                  width: double.infinity,
                  fit: BoxFit.fitWidth,
                  errorBuilder: (_, __, ___) => _mediaMissing('Image locale non disponible'),
                ),
        ),
      );
    }

    final simpleLinkMatch = RegExp(r'\[(.*?)\]\((.*?)\)').firstMatch(trimmed);

    // ── 2. VIDEO  ────────────────────────────────────────────────
    final isVideoPrefix = trimmed.contains('🎬') || trimmed.contains('🎥');
    final isVideoExtension = RegExp(r'\.(mp4|avi|mov|mkv|webm)(\?|$)').hasMatch(trimmed);
    if (simpleLinkMatch != null && (isVideoPrefix || isVideoExtension)) {
      final videoTitle = simpleLinkMatch.group(1) ?? 'Vidéo';
      final videoUrl = _sanitize(simpleLinkMatch.group(2) ?? '');
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🎬 $videoTitle',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
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

    // ── 3. PDF  ──────────────────────────────────────────────────
    final isPdfPrefix = trimmed.contains('📄') || trimmed.contains('📕') || trimmed.contains('PDF');
    final isPdfExtension = RegExp(r'\.(pdf)(\?|$)').hasMatch(trimmed);
    if (simpleLinkMatch != null && (isPdfPrefix || isPdfExtension)) {
      final pdfTitle = simpleLinkMatch.group(1) ?? 'Document PDF';
      final pdfUrl = _sanitize(simpleLinkMatch.group(2) ?? '');
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Container(
          height: 550, // Contenu complet visible — zoom et défilement horizontal
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
                    debugPrint('Preview PDF load error: ${details.description}');
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
                            title: title.isNotEmpty ? title : pdfTitle,
                          ),
                        ),
                      ),
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
      );
    }

    // ── Texte ordinaire  ─────────────────────────────────────────
    final cleaned = trimmed
        .replaceAll(RegExp(r'\*\*'), '')
        .replaceAll(RegExp(r'__'), '')
        .replaceAll(RegExp(r'\[(.*?)\]\((.*?)\)'), r'$1');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        cleaned,
        style: const TextStyle(fontSize: 16, height: 1.6),
      ),
    );
  }

  Widget _mediaMissing(String message) => Container(
        padding: const EdgeInsets.all(12),
        color: Colors.grey.shade200,
        child: Text(message),
      );
}