import 'dart:io';
import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    final lines = content.split('\n');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aperçu de l’article'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            summary,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          ...lines.map(_buildLine),
        ],
      ),
    );
  }

  Widget _buildLine(String line) {
    final trimmed = line.trim();

    if (trimmed.isEmpty) {
      return const SizedBox(height: 10);
    }

    if (trimmed.startsWith('# ')) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          trimmed.substring(2),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    if (trimmed.startsWith('## ')) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          trimmed.substring(3),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

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

    if (trimmed.startsWith('> ')) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(color: Colors.blue.shade400, width: 4),
          ),
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        trimmed,
        style: const TextStyle(
          fontSize: 16,
          height: 1.6,
        ),
      ),
    );
  }
}