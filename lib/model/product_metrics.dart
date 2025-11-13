import 'package:equatable/equatable.dart';

class ProductMetrics extends Equatable {
  final int views;
  final int likes;
  final int reviews;
  final double rating;
  final int inCarts;
  final int shares;

  const ProductMetrics({
    this.views = 0,
    this.likes = 0,
    this.reviews = 0,
    this.rating = 0,
    this.inCarts = 0,
    this.shares = 0,
  });

  ProductMetrics copyWith({
    int? views,
    int? likes,
    int? reviews,
    double? rating,
    int? inCarts,
    int? shares,
  }) {
    return ProductMetrics(
      views: views ?? this.views,
      likes: likes ?? this.likes,
      reviews: reviews ?? this.reviews,
      rating: rating ?? this.rating,
      inCarts: inCarts ?? this.inCarts,
      shares: shares ?? this.shares,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'views': views,
      'likes': likes,
      'reviews': reviews,
      'rating': rating,
      'inCarts': inCarts,
      'shares': shares,
    };
  }

  factory ProductMetrics.fromJson(Map<String, dynamic> json) {
    return ProductMetrics(
      views: json['views'] as int? ?? 0,
      likes: json['likes'] as int? ?? 0,
      reviews: json['reviews'] as int? ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      inCarts: json['inCarts'] as int? ?? 0,
      shares: json['shares'] as int? ?? 0,
    );
  }

  static ProductMetrics randomSeed(int seed) {
    return ProductMetrics(
      views: 120 + seed * 17,
      likes: 35 + seed * 7,
      reviews: 10 + seed,
      rating: 3.8 + (seed % 3) * 0.2,
      inCarts: 8 + seed,
      shares: 5 + seed,
    );
  }

  @override
  List<Object?> get props => [views, likes, reviews, rating, inCarts, shares];
}
