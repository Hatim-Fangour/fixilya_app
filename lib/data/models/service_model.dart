class ServiceModel {
  final String id;
  final String name;
  final String category;
  final String? description;
  final String? icon;
  final double basePrice;
  final String pricingUnit; // 'hourly', 'fixed', 'per_item'
  final bool isActive;
  final int popularity;
  final List<String> tags;
  final Map<String, dynamic>? metadata;

  ServiceModel({
    required this.id,
    required this.name,
    required this.category,
    this.description,
    this.icon,
    required this.basePrice,
    this.pricingUnit = 'hourly',
    this.isActive = true,
    this.popularity = 0,
    this.tags = const [],
    this.metadata,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      description: json['description'],
      icon: json['icon'],
      basePrice: (json['basePrice'] ?? 0).toDouble(),
      pricingUnit: json['pricingUnit'] ?? 'hourly',
      isActive: json['isActive'] ?? true,
      popularity: json['popularity'] ?? 0,
      tags: List<String>.from(json['tags'] ?? []),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'description': description,
    'icon': icon,
    'basePrice': basePrice,
    'pricingUnit': pricingUnit,
    'isActive': isActive,
    'popularity': popularity,
    'tags': tags,
    'metadata': metadata,
  };
}
