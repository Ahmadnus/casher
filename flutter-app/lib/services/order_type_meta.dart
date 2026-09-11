import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Single source of truth for the sales channels (order sources). Values match the Laravel
/// `order_type` enum / `channels.code` exactly — never invent a different
/// string elsewhere.
///
/// The type IS the channel code: the backend resolves it to a channel row to
/// apply per-channel pricing and commission.
class OrderType {
  static const String takeaway = 'takeaway';
  static const String delivery = 'delivery';
  static const String dineIn = 'dine_in';
  static const String coffeeShop = 'coffee_shop';

  /// Third-party delivery platforms. Orders on these carry the platform's own
  /// reference number and are charged a commission.
  static const String talabaty = 'talabaty'; // displayed as "Talabat"
  static const String eshyai = 'eshyai';
  static const String otlob = 'otlob';

  /// Catch-all source for orders that fit none of the named channels.
  static const String other = 'other';

  static const List<String> all = [
    coffeeShop,
    talabaty,
    otlob,
    other,
    takeaway,
    delivery,
    dineIn,
    eshyai,
  ];

  /// The four primary order sources for the weekly inventory report,
  /// in the order they are shown.
  static const List<String> primarySources = [coffeeShop, talabaty, otlob, other];

  /// Channels operated by an external aggregator rather than in-house.
  static const List<String> thirdParty = [talabaty, eshyai, otlob];

  static bool isThirdParty(String type) => thirdParty.contains(type);

  static String label(String type) => switch (type) {
        delivery => 'توصيل',
        dineIn => 'طاولة',
        coffeeShop => 'كوفي شوب',
        talabaty => 'طلبات',
        eshyai => 'اشيائي',
        otlob => 'أطلب',
        other => 'أخرى',
        _ => 'استلام',
      };

  /// English name, for bilingual headers in reports.
  static String labelEn(String type) => switch (type) {
        delivery => 'Delivery',
        dineIn => 'Dine-in',
        coffeeShop => 'Coffee Shop',
        talabaty => 'Talabat',
        eshyai => 'Eshyai',
        otlob => 'Otlob',
        other => 'Other',
        _ => 'Takeaway',
      };

  static IconData icon(String type) => switch (type) {
        delivery => Icons.delivery_dining,
        dineIn => Icons.table_bar,
        coffeeShop => Icons.coffee,
        talabaty => Icons.moped,
        eshyai => Icons.shopping_bag,
        otlob => Icons.two_wheeler,
        other => Icons.more_horiz,
        _ => Icons.store,
      };

  static Color color(String type) => switch (type) {
        delivery => AppTheme.accent,
        dineIn => AppTheme.accentGold,
        coffeeShop => AppTheme.warning,
        talabaty => AppTheme.talabaty,
        eshyai => AppTheme.eshyai,
        otlob => AppTheme.otlob,
        other => AppTheme.other,
        _ => AppTheme.success,
      };
}
