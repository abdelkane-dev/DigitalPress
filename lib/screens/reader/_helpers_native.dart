import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

/// Builds a local PDF viewer using dart:io File.
/// Only called on native platforms (guarded by !kIsWeb in reader_screen.dart).
Widget buildLocalPdfViewer(
  String filePath,
  PdfViewerController controller, {
  PdfPageLayoutMode pageLayoutMode = PdfPageLayoutMode.single,
  PdfScrollDirection scrollDirection = PdfScrollDirection.horizontal,
  void Function(int pageCount)? onDocumentLoaded,
  void Function(String error)? onDocumentLoadFailed,
  void Function(dynamic details)? onPageChanged,
}) {
  return SfPdfViewer.file(
    io.File(filePath),
    controller: controller,
    pageLayoutMode: pageLayoutMode,
    scrollDirection: scrollDirection,
    onDocumentLoaded: onDocumentLoaded != null
        ? (details) => onDocumentLoaded(details.document.pages.count)
        : null,
    onDocumentLoadFailed: onDocumentLoadFailed != null
        ? (details) => onDocumentLoadFailed(details.description)
        : null,
    onPageChanged: onPageChanged,
  );
}

/// Builds a local image using dart:io File.
/// Only called on native platforms (guarded by !kIsWeb in reader_screen.dart).
Widget buildLocalImage(String imageUrl) {
  return Image.file(
    io.File(imageUrl),
    width: double.infinity,
    fit: BoxFit.fitWidth,
    errorBuilder: (context, error, stackTrace) => Container(
      padding: const EdgeInsets.all(12),
      color: Colors.grey.shade200,
      child: const Text('Image locale non disponible'),
    ),
  );
}
