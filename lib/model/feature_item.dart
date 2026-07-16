class FeatureItem {
  final int id;
  final String title;
  final String description;
  final String scope; // admin | publisher | both
  final String status; // a_venir | en_cours | fait | rejete
  final String statusDisplay;
  final String? createdByName;
  final DateTime createdAt;

  FeatureItem({
    required this.id,
    required this.title,
    required this.description,
    required this.scope,
    required this.status,
    required this.statusDisplay,
    required this.createdByName,
    required this.createdAt,
  });

  factory FeatureItem.fromJson(Map<String, dynamic> json) {
    return FeatureItem(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      scope: json['scope'] as String? ?? 'both',
      status: json['status'] as String? ?? 'a_venir',
      statusDisplay: json['status_display'] as String? ?? 'À venir',
      createdByName: json['created_by_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
