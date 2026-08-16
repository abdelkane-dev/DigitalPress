import 'package:flutter/material.dart';

/// Widget invisible aux interactions tactiles (IgnorePointer) qui affiche
/// un filigrane de sécurité répétitif par-dessus le contenu.
class WatermarkOverlay extends StatelessWidget {
  final String userId; // ID unique de l'utilisateur.
  final String email; // Email de l'utilisateur.

  const WatermarkOverlay({
    super.key,
    required this.userId,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: List.generate(3, (index) {
          // Disposition en diagonale pour couvrir les zones clés sans empêcher la lecture.
          return Positioned(
            top: 100.0 + (index * 200.0),
            left: index % 2 == 0 ? 50.0 : 150.0,
            child: Transform.rotate(
              angle: -0.5, // Inclinaison pour plus de visibilité DRM.
              child: Opacity(
                opacity:
                    0.1, // Très faible opacité pour ne pas gêner le confort de lecture.
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ID: $userId',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      email,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
