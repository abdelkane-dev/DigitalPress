import 'package:flutter/material.dart';

class Category {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final int journalCount;
  final String imageUrl;

  Category({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    this.journalCount = 0,
    this.imageUrl = '',
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      icon: _getIconFromString(json['icon'] as String?),
      color: _getColorFromHex(json['color'] as String?),
      journalCount: json['journal_count'] as int? ?? 0,
      imageUrl: json['image_url'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': _getIconString(icon),
      'color': _getColorHex(color),
      'journal_count': journalCount,
      'image_url': imageUrl,
    };
  }

  static IconData _getIconFromString(String? iconName) {
    switch (iconName) {
      case 'newspaper':
        return Icons.newspaper_rounded;
      case 'sports':
        return Icons.sports_soccer_rounded;
      case 'culture':
        return Icons.theater_comedy_rounded;
      case 'economy':
        return Icons.trending_up_rounded;
      case 'tech':
        return Icons.computer_rounded;
      case 'health':
        return Icons.favorite_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  static String _getIconString(IconData icon) {
    if (icon == Icons.newspaper_rounded) return 'newspaper';
    if (icon == Icons.sports_soccer_rounded) return 'sports';
    if (icon == Icons.theater_comedy_rounded) return 'culture';
    if (icon == Icons.trending_up_rounded) return 'economy';
    if (icon == Icons.computer_rounded) return 'tech';
    if (icon == Icons.favorite_rounded) return 'health';
    return 'category';
  }

  static Color _getColorFromHex(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF2C74B3);
    final hexColor = hex.replaceAll('#', '');
    return Color(int.parse('FF$hexColor', radix: 16));
  }

  static String _getColorHex(Color color) {
    // ignore: deprecated_member_use
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  Category copyWith({
    String? id,
    String? name,
    String? description,
    IconData? icon,
    Color? color,
    int? journalCount,
    String? imageUrl,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      journalCount: journalCount ?? this.journalCount,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
