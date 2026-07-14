import 'package:flutter/material.dart';

/// Maps the heroicon-style key returned by the backend
/// (`heroicon-o-cake`, `restaurant`, `local_cafe`, etc.) to a Material
/// icon. Centralised so transactions, dashboard cards and budgets all
/// resolve the same icon for the same key.
IconData categoryIconFor(String rawKey) {
  final key = rawKey.toLowerCase();
  if (key.contains('cake') ||
      key.contains('restaurant') ||
      key.contains('food')) {
    return Icons.restaurant_rounded;
  }
  if (key.contains('cafe') || key.contains('coffee')) {
    return Icons.local_cafe_rounded;
  }
  if (key.contains('truck') ||
      key.contains('car') ||
      key.contains('directions')) {
    return Icons.directions_car_rounded;
  }
  if (key.contains('shopping') || key.contains('cart')) {
    return Icons.shopping_cart_rounded;
  }
  if (key.contains('payment') ||
      key.contains('cash') ||
      key.contains('salary') ||
      key.contains('banknote') ||
      key.contains('wallet')) {
    return Icons.payments_rounded;
  }
  if (key.contains('home') || key.contains('house')) {
    return Icons.home_rounded;
  }
  if (key.contains('health') || key.contains('medical')) {
    return Icons.health_and_safety_rounded;
  }
  if (key.contains('book') || key.contains('education')) {
    return Icons.menu_book_rounded;
  }
  if (key.contains('movie') ||
      key.contains('entertainment') ||
      key.contains('film')) {
    return Icons.movie_outlined;
  }
  if (key.contains('plane') || key.contains('flight') ||
      key.contains('travel')) {
    return Icons.flight_takeoff_rounded;
  }
  if (key.contains('phone') || key.contains('mobile')) {
    return Icons.phone_iphone_rounded;
  }
  if (key.contains('gift')) return Icons.card_giftcard_rounded;
  if (key.contains('savings') || key.contains('piggy')) {
    return Icons.savings_rounded;
  }
  return Icons.category_rounded;
}

/// Tries to parse the optional `#RRGGBB` colour the backend stores per
/// category. Returns `null` when the value is missing/invalid so callers
/// can fall back to the theme.
Color? categoryAccentColor(String raw) {
  if (raw.isEmpty) return null;
  var s = raw.trim();
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length == 6) {
    final v = int.tryParse(s, radix: 16);
    if (v != null) return Color(0xFF000000 | v);
  }
  if (s.length == 8) {
    final v = int.tryParse(s, radix: 16);
    if (v != null) return Color(v);
  }
  return null;
}
