import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────────────────────────────────────

enum ProductCategory {
  all,
  materials,
  tools,
  pharmacy,
  electrical,
  plumbing,
  paint,
  cleaning,
}

extension ProductCategoryX on ProductCategory {
  String get label {
    switch (this) {
      case ProductCategory.all:        return 'All';
      case ProductCategory.materials:  return 'Materials';
      case ProductCategory.tools:      return 'Tools';
      case ProductCategory.pharmacy:   return 'Pharmacy';
      case ProductCategory.electrical: return 'Electrical';
      case ProductCategory.plumbing:   return 'Plumbing';
      case ProductCategory.paint:      return 'Paint';
      case ProductCategory.cleaning:   return 'Cleaning';
    }
  }

  String get value {
    switch (this) {
      case ProductCategory.all:        return 'all';
      case ProductCategory.materials:  return 'materials';
      case ProductCategory.tools:      return 'tools';
      case ProductCategory.pharmacy:   return 'pharmacy';
      case ProductCategory.electrical: return 'electrical';
      case ProductCategory.plumbing:   return 'plumbing';
      case ProductCategory.paint:      return 'paint';
      case ProductCategory.cleaning:   return 'cleaning';
    }
  }

  static ProductCategory fromValue(String value) {
    return ProductCategory.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ProductCategory.all,
    );
  }
}

enum SortOption {
  popular,
  priceAsc,
  priceDesc,
  newest,
  rating,
}

extension SortOptionX on SortOption {
  String get label {
    switch (this) {
      case SortOption.popular:   return 'Most Popular';
      case SortOption.priceAsc:  return 'Price: Low to High';
      case SortOption.priceDesc: return 'Price: High to Low';
      case SortOption.newest:    return 'Newest First';
      case SortOption.rating:    return 'Top Rated';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider (vendor / seller)
// ─────────────────────────────────────────────────────────────────────────────

class ProductProvider {
  final String id;
  final String name;
  final String? logo;
  final double rating;
  final int totalSales;
  final String? city;

  const ProductProvider({
    required this.id,
    required this.name,
    this.logo,
    this.rating = 4.0,
    this.totalSales = 0,
    this.city,
  });

  factory ProductProvider.fromJson(Map<String, dynamic> json) {
    return ProductProvider(
      id:         json['id']?.toString()         ?? '',
      name:       json['name']?.toString()       ?? 'Unknown Provider',
      logo:       json['logo']?.toString(),
      rating:     (json['rating'] as num?)?.toDouble() ?? 4.0,
      totalSales: (json['totalSales'] as num?)?.toInt() ?? 0,
      city:       json['city']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id':         id,
    'name':       name,
    if (logo != null)   'logo':       logo,
    'rating':     rating,
    'totalSales': totalSales,
    if (city != null)   'city':       city,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// ProductModel
// ─────────────────────────────────────────────────────────────────────────────

class ProductModel {
  final String id;
  final String name;
  final String description;
  final double price;           // in MAD
  final double? originalPrice;  // null if no discount
  final ProductCategory category;
  final ProductProvider provider;
  final List<String> images;   // Cloudinary or placeholder URLs
  final double rating;         // 0.0–5.0
  final int reviewCount;
  final bool inStock;
  final int stockCount;
  final List<String> tags;
  final bool featured;
  final DateTime createdAt;
  // Variant selectors — empty list means this product has no variants of that type.
  // Colors are hex strings (e.g. '#E74C3C'). Sizes are display labels (e.g. 'M', '40mm').
  final List<String> colors;
  final List<String> sizes;

  const ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.originalPrice,
    required this.category,
    required this.provider,
    required this.images,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.inStock = true,
    this.stockCount = 0,
    this.tags = const [],
    this.featured = false,
    required this.createdAt,
    this.colors = const [],
    this.sizes = const [],
  });

  // ── Computed properties ──────────────────────────────────────────────────

  bool get hasDiscount => originalPrice != null && originalPrice! > price;

  int get discountPercent {
    if (!hasDiscount) return 0;
    return (((originalPrice! - price) / originalPrice!) * 100).round();
  }

  String get primaryImage =>
      images.isNotEmpty ? images.first : 'https://via.placeholder.com/300';

  String get priceFormatted => '${price.toStringAsFixed(0)} MAD';

  String get originalPriceFormatted =>
      originalPrice != null ? '${originalPrice!.toStringAsFixed(0)} MAD' : '';

  // ── Serialization ──────────────────────────────────────────────────────

  factory ProductModel.fromJson(Map<String, dynamic> json, {String? id}) {
    return ProductModel(
      id:            id ?? json['id']?.toString() ?? '',
      name:          json['name']?.toString()        ?? '',
      description:   json['description']?.toString() ?? '',
      price:         (json['price'] as num?)?.toDouble() ?? 0.0,
      originalPrice: (json['originalPrice'] as num?)?.toDouble(),
      category:      ProductCategoryX.fromValue(json['category']?.toString() ?? 'all'),
      provider: json['provider'] is Map
          ? ProductProvider.fromJson(Map<String, dynamic>.from(json['provider'] as Map))
          : const ProductProvider(id: '', name: 'Unknown'),
      images: (json['images'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      rating:      (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      inStock:     json['inStock'] as bool? ?? true,
      stockCount:  (json['stockCount'] as num?)?.toInt() ?? 0,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      featured:  json['featured'] as bool? ?? false,
      createdAt: _parseDate(json['createdAt']),
      colors: (json['colors'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      sizes: (json['sizes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  factory ProductModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ProductModel.fromJson(data, id: doc.id);
  }

  Map<String, dynamic> toJson() => {
    'name':          name,
    'description':   description,
    'price':         price,
    if (originalPrice != null) 'originalPrice': originalPrice,
    'category':      category.value,
    'provider':      provider.toJson(),
    'images':        images,
    'rating':        rating,
    'reviewCount':   reviewCount,
    'inStock':       inStock,
    'stockCount':    stockCount,
    'tags':          tags,
    'featured':      featured,
    'createdAt':     Timestamp.fromDate(createdAt),
    if (colors.isNotEmpty) 'colors': colors,
    if (sizes.isNotEmpty)  'sizes':  sizes,
  };

  ProductModel copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    double? originalPrice,
    ProductCategory? category,
    ProductProvider? provider,
    List<String>? images,
    double? rating,
    int? reviewCount,
    bool? inStock,
    int? stockCount,
    List<String>? tags,
    bool? featured,
    DateTime? createdAt,
    List<String>? colors,
    List<String>? sizes,
  }) {
    return ProductModel(
      id:            id            ?? this.id,
      name:          name          ?? this.name,
      description:   description   ?? this.description,
      price:         price         ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      category:      category      ?? this.category,
      provider:      provider      ?? this.provider,
      images:        images        ?? this.images,
      rating:        rating        ?? this.rating,
      reviewCount:   reviewCount   ?? this.reviewCount,
      inStock:       inStock       ?? this.inStock,
      stockCount:    stockCount    ?? this.stockCount,
      tags:          tags          ?? this.tags,
      featured:      featured      ?? this.featured,
      createdAt:     createdAt     ?? this.createdAt,
      colors:        colors        ?? this.colors,
      sizes:         sizes         ?? this.sizes,
    );
  }

  @override
  bool operator ==(Object other) => other is ProductModel && id == other.id;

  @override
  int get hashCode => id.hashCode;

  // ── Helpers ──────────────────────────────────────────────────────────────

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp)  return value.toDate();
    if (value is DateTime)   return value;
    if (value is String)     return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
