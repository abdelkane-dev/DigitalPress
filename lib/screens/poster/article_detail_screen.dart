import 'package:flutter/material.dart';
import '../../model/publication.dart';

class ArticleDetailScreen extends StatelessWidget {
  final Publication publication;

  const ArticleDetailScreen({super.key, required this.publication});

  @override
  Widget build(BuildContext context) {
    final contentText = publication.content.isNotEmpty ? publication.content : publication.description;
    final lines = contentText.split('\n');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails de l\'article'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (publication.coverImage.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.network(
                publication.coverImage,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox.shrink();
                },
              ),
            ),
          const SizedBox(height: 16),

          Text(
            publication.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0A2647),
            ),
          ),

          const SizedBox(height: 10),

          Text(
            publication.description,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 24),

          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                line,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}