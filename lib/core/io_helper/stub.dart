import 'package:flutter/widgets.dart';

/// Stub for web - dart:io File not available.
Widget buildLocalPdfViewer({
  required String filePath,
  required dynamic controller,
  required dynamic pageLayoutMode,
  required dynamic scrollDirection,
  required dynamic onDocumentLoaded,
  dynamic onDocumentLoadFailed,
  dynamic onPageChanged,
}) {
  return const SizedBox.shrink();
}

/// Stub for web - dart:io File not available.
Widget buildLocalImage({
  required String path,
  required double? width,
  required double? height,
  required BoxFit fit,
  Widget Function(BuildContext, Object?, StackTrace?)? errorBuilder,
}) {
  return const SizedBox.shrink();
}

/// Stub for web - always returns false.
Future<bool> nativeFileExists(String path) async => false;
