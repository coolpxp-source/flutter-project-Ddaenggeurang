import 'package:cloud_firestore/cloud_firestore.dart';

enum ProductStatus { selling, reserved, sold }

extension ProductStatusX on ProductStatus {
  String get value => name; // "selling" | "reserved" | "sold"

  static ProductStatus fromString(String value) {
    return ProductStatus.values.firstWhere(
          (e) => e.name == value,
      orElse: () => ProductStatus.selling,
    );
  }
}

class PriceComparison {
  final String source;
  final num price;
  final String url;

  PriceComparison({
    required this.source,
    required this.price,
    required this.url,
  });

  factory PriceComparison.fromMap(Map<String, dynamic> map) {
    return PriceComparison(
      source: map['source'] ?? '',
      price: map['price'] ?? 0,
      url: map['url'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'source': source,
      'price': price,
      'url': url,
    };
  }
}

class MarketProduct {
  final String productId;
  final String sellerId;
  final String sellerName;
  final String sellerAvatarUrl;
  final String title;
  final num price;
  final String description;
  final List<String> images;
  final ProductStatus status;
  final String category;
  final List<PriceComparison> priceComparisons;
  final GeoPoint? locationGeo;
  final String? verifiedDong;
  final bool isUrgent;
  final bool isNegotiable;
  final bool isDirectDeal;
  final DateTime createdAt;
  final DateTime updatedAt;

  MarketProduct({
    required this.productId,
    required this.sellerId,
    required this.sellerName,
    required this.sellerAvatarUrl,
    required this.title,
    required this.price,
    required this.description,
    required this.images,
    required this.status,
    required this.category,
    required this.priceComparisons,
    this.locationGeo,
    this.verifiedDong,
    this.isUrgent = false,
    this.isNegotiable = false,
    this.isDirectDeal = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MarketProduct.fromMap(String productId, Map<String, dynamic> map) {
    return MarketProduct(
      productId: productId,
      sellerId: map['sellerId'] ?? '',
      sellerName: map['sellerName'] ?? '',
      sellerAvatarUrl: map['sellerAvatarUrl'] ?? '',
      title: map['title'] ?? '',
      price: map['price'] ?? 0,
      description: map['description'] ?? '',
      images: List<String>.from(map['images'] ?? []),
      status: ProductStatusX.fromString(map['status'] ?? 'selling'),
      category: map['category'] ?? '',
      priceComparisons: (map['priceComparisons'] as List<dynamic>? ?? [])
          .map((e) => PriceComparison.fromMap(e as Map<String, dynamic>))
          .toList(),
      locationGeo: map['locationGeo'] as GeoPoint?,
      verifiedDong: map['verifiedDong'] as String?,
      isUrgent: map['isUrgent'] ?? false,
      isNegotiable: map['isNegotiable'] ?? false,
      isDirectDeal: map['isDirectDeal'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory MarketProduct.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MarketProduct.fromMap(doc.id, data);
  }

  Map<String, dynamic> toMap() {
    return {
      'sellerId': sellerId,
      'sellerName': sellerName,
      'sellerAvatarUrl': sellerAvatarUrl,
      'title': title,
      'price': price,
      'description': description,
      'images': images,
      'status': status.value,
      'category': category,
      'priceComparisons': priceComparisons.map((e) => e.toMap()).toList(),
      'locationGeo': locationGeo,
      'verifiedDong': verifiedDong,
      'isUrgent': isUrgent,
      'isNegotiable': isNegotiable,
      'isDirectDeal': isDirectDeal,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}