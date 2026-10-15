import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

/// Builds a local PDF viewer using dart:io File (native only).
Widget buildLocalPdfViewer({
  required String filePath,
  required PdfViewerController controller,
  required PdfPageLayoutMode pageLayoutMode,
  required PdfScrollDirection scrollDirection,
  required void Function(PdfDocumentLoadedDetails) onDocumentLoaded,
  void Function(PdfDocumentLoadFailedDetails)? onDocumentLoadFailed,
  void Function(PdfPageChangedDetails)? onPageChanged,
}) {
  return SfPdfViewer.file(
    io.File(filePath),
    controller: controller,
    pageLayoutMode: pageLayoutMode,
    scrollDirection: scrollDirection,
    onDocumentLoaded: onDocumentLoaded,
    onDocumentLoadFailed: onDocumentLoadFailed,
    onPageChanged: onPageChanged,
  );
}

/// Builds a local Image using dart:io File (native only).
Widget buildLocalImage({
  required String path,
  required double? width,
  required double? height,
  required BoxFit fit,
  Widget Function(BuildContext, Object?, StackTrace?)? errorBuilder,
}) {
  return Image.file(
    io.File(path),
    width: width,
    height: height,
    fit: fit,
    errorBuilder: errorBuilder,
  );
}

/// Check if a file exists at the given path (native only).
Future<bool> nativeFileExists(String path) async {
  return io.File(path).exists();
}
