class Journal {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final String category;
  final String categoryId;
  final double price;
  final String imageUrl;
  final String pdfUrl;
  final DateTime publishedDate;
  final bool isNew;
  final int pageCount;
  final String publisher;
  final List<String> tags;

  Journal({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.category,
    required this.categoryId,
    required this.price,
    required this.imageUrl,
    required this.pdfUrl,
    required this.publishedDate,
    this.isNew = false,
    required this.pageCount,
    required this.publisher,
    this.tags = const [],
  });

  factory Journal.fromJson(Map<String, dynamic> json) {
    return Journal(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String,
      categoryId: json['category_id'] as String,
      price: (json['price'] as num).toDouble(),
      imageUrl: json['image_url'] as String,
      pdfUrl: json['pdf_url'] as String,
      publishedDate: DateTime.parse(json['published_date'] as String),
      isNew: json['is_new'] as bool? ?? false,
      pageCount: json['page_count'] as int? ?? 0,
      publisher: json['publisher'] as String? ?? '',
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'description': description,
      'category': category,
      'category_id': categoryId,
      'price': price,
      'image_url': imageUrl,
      'pdf_url': pdfUrl,
      'published_date': publishedDate.toIso8601String(),
      'is_new': isNew,
      'page_count': pageCount,
      'publisher': publisher,
      'tags': tags,
    };
  }

  Journal copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? description,
    String? category,
    String? categoryId,
    double? price,
    String? imageUrl,
    String? pdfUrl,
    DateTime? publishedDate,
    bool? isNew,
    int? pageCount,
    String? publisher,
    List<String>? tags,
  }) {
    return Journal(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      category: category ?? this.category,
      categoryId: categoryId ?? this.categoryId,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      publishedDate: publishedDate ?? this.publishedDate,
      isNew: isNew ?? this.isNew,
      pageCount: pageCount ?? this.pageCount,
      publisher: publisher ?? this.publisher,
      tags: tags ?? this.tags,
    );
  }
}
