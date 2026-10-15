import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

/// Stub web — ces fonctions ne sont JAMAIS appelées sur web
/// (guardées par !kIsWeb dans reader_screen.dart), mais le fichier
/// doit exister pour que le web build compile.

Widget buildLocalPdfViewer(
  String filePath,
  PdfViewerController controller, {
  PdfPageLayoutMode pageLayoutMode = PdfPageLayoutMode.single,
  PdfScrollDirection scrollDirection = PdfScrollDirection.horizontal,
  void Function(int pageCount)? onDocumentLoaded,
  void Function(String error)? onDocumentLoadFailed,
  void Function(dynamic details)? onPageChanged,
}) {
  // Ne devrait JAMAIS être appelé sur web
  return const SizedBox.shrink();
}

Widget buildLocalImage(String imageUrl) {
  // Ne devrait JAMAIS être appelé sur web
  return const SizedBox.shrink();
}
