// Modèles pour les plans d'abonnement et abonnements clients.

class AbonnementPlan {
  final int id;
  final String name;
  final int? publisherId;
  final String? publisherName;
  final String description;
  final double prix;
  final String period; // monthly, quarterly, yearly
  final int maxPublications;
  final String features;
  final List<String> featuresList;
  final bool isActive;

  AbonnementPlan({
    required this.id,
    required this.name,
    this.publisherId,
    this.publisherName,
    required this.description,
    required this.prix,
    required this.period,
    required this.maxPublications,
    required this.features,
    required this.featuresList,
    required this.isActive,
  });

  factory AbonnementPlan.fromJson(Map<String, dynamic> json) {
    return AbonnementPlan(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      publisherId: json['publisher'],
      publisherName: json['publisher_name'],
      description: json['description'] ?? '',
      prix: double.tryParse(json['prix']?.toString() ?? '0') ?? 0.0,
      period: json['period'] ?? 'monthly',
      maxPublications: json['max_publications'] ?? 0,
      features: json['features'] ?? '',
      featuresList: json['features_list'] is List
          ? List<String>.from(json['features_list'])
          : [],
      isActive: json['is_active'] ?? true,
    );
  }

  String get periodLabel {
    switch (period) {
      case 'monthly':
        return 'Mois';
      case 'quarterly':
        return 'Trimestre';
      case 'yearly':
        return 'An';
      default:
        return period;
    }
  }
}

class Abonnement {
  final int id;
  final int readerId;
  final String readerUsername;
  final int? publicationId;
  final String? publicationTitle;
  final int? planId;
  final String? planName;
  final int? publisherId;
  final String? publisherName;
  final double montant;
  final String status; // active, expired, cancelled, pending
  final DateTime? startDate;
  final DateTime? endDate;
  final bool autoRenew;
  final String transactionRef;
  final bool isActive;

  Abonnement({
    required this.id,
    required this.readerId,
    required this.readerUsername,
    this.publicationId,
    this.publicationTitle,
    this.planId,
    this.planName,
    this.publisherId,
    this.publisherName,
    required this.montant,
    required this.status,
    this.startDate,
    this.endDate,
    required this.autoRenew,
    required this.transactionRef,
    required this.isActive,
  });

  factory Abonnement.fromJson(Map<String, dynamic> json) {
    return Abonnement(
      id: json['id'] ?? 0,
      readerId: json['reader'] ?? 0,
      readerUsername: json['reader_username'] ?? '',
      publicationId: json['publication'],
      publicationTitle: json['publication_title'],
      planId: json['plan'],
      planName: json['plan_name'],
      publisherId: json['publisher'],
      publisherName: json['publisher_name'],
      montant: double.tryParse(json['montant']?.toString() ?? '0') ?? 0.0,
      status: json['status'] ?? 'pending',
      startDate: json['start_date'] != null ? DateTime.tryParse(json['start_date']) : null,
      endDate: json['end_date'] != null ? DateTime.tryParse(json['end_date']) : null,
      autoRenew: json['auto_renew'] ?? false,
      transactionRef: json['transaction_ref'] ?? '',
      isActive: json['is_active'] ?? false,
    );
  }
}
