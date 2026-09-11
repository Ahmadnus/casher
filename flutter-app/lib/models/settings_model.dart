import '../core/json_parsing.dart';

class SettingsModel {
  final String name;
  final String? logoUrl;
  final String currency;
  final String currencySymbol;
  final String? address;
  final String? phone;
  final double taxRate;
  final String? receiptHeader;
  final String? receiptFooter;

  const SettingsModel({
    required this.name,
    this.logoUrl,
    this.currency = 'JOD',
    this.currencySymbol = 'د.أ',
    this.address,
    this.phone,
    this.taxRate = 0,
    this.receiptHeader,
    this.receiptFooter,
  });

  factory SettingsModel.fromJson(Map<String, dynamic> json) {
    return SettingsModel(
      name: json['name'] as String? ?? 'Restaurant',
      logoUrl: json['logo_url'] as String?,
      currency: json['currency'] as String? ?? 'JOD',
      currencySymbol: json['currency_symbol'] as String? ?? 'د.أ',
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      taxRate: asDouble(json['tax_rate']),
      receiptHeader: json['receipt_header'] as String?,
      receiptFooter: json['receipt_footer'] as String?,
    );
  }

  factory SettingsModel.defaults() => const SettingsModel(name: 'مطعمي');
}
