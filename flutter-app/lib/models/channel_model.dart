import '../core/json_parsing.dart';

/// A sales channel as configured on the backend (`channels` table).
/// [code] matches the `order_type` string sent on every order/invoice.
class ChannelModel {
  final int id;
  final String code;
  final String name;
  final String? nameAr;
  final double commissionRate;
  final bool isThirdParty;
  final bool isActive;
  final int sortOrder;

  ChannelModel({
    required this.id,
    required this.code,
    required this.name,
    this.nameAr,
    required this.commissionRate,
    required this.isThirdParty,
    required this.isActive,
    required this.sortOrder,
  });

  /// Arabic label when the backend supplies one, English name otherwise.
  String get displayName =>
      (nameAr != null && nameAr!.isNotEmpty) ? nameAr! : name;

  factory ChannelModel.fromJson(Map<String, dynamic> json) => ChannelModel(
        id: asInt(json['id']),
        code: asString(json['code']),
        name: asString(json['name']),
        nameAr: json['name_ar'] as String?,
        commissionRate: asDouble(json['commission_rate']),
        isThirdParty: asBool(json['is_third_party']),
        isActive: asBool(json['is_active']),
        sortOrder: asInt(json['sort_order']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'name_ar': nameAr,
        'commission_rate': commissionRate,
        'is_third_party': isThirdParty,
        'is_active': isActive,
        'sort_order': sortOrder,
      };
}

/// One line of `/reports/sales-by-channel` — a channel's totals for a period.
class ChannelSalesModel {
  final String channelCode;
  final String channelName;
  final String? channelNameAr;
  final bool isThirdParty;
  final double totalSales;
  final double commission;
  final double netSales;
  final double deliveryFee;
  final double discount;
  final double averageInvoice;
  final int invoiceCount;
  final double sharePercent;

  ChannelSalesModel({
    required this.channelCode,
    required this.channelName,
    this.channelNameAr,
    required this.isThirdParty,
    required this.totalSales,
    required this.commission,
    required this.netSales,
    required this.deliveryFee,
    required this.discount,
    required this.averageInvoice,
    required this.invoiceCount,
    required this.sharePercent,
  });

  String get displayName => (channelNameAr != null && channelNameAr!.isNotEmpty)
      ? channelNameAr!
      : channelName;

  factory ChannelSalesModel.fromJson(Map<String, dynamic> json) =>
      ChannelSalesModel(
        channelCode: asString(json['channel_code']),
        channelName: asString(json['channel_name']),
        channelNameAr: json['channel_name_ar'] as String?,
        isThirdParty: asBool(json['is_third_party']),
        totalSales: asDouble(json['total_sales']),
        commission: asDouble(json['commission']),
        netSales: asDouble(json['net_sales']),
        deliveryFee: asDouble(json['delivery_fee']),
        discount: asDouble(json['discount']),
        averageInvoice: asDouble(json['average_invoice']),
        invoiceCount: asInt(json['invoice_count']),
        sharePercent: asDouble(json['share_percent']),
      );
}

/// Full `/reports/sales-by-channel` payload: per-channel rows plus the
/// in-house / third-party / overall roll-ups.
class ChannelSalesReport {
  final String dateFrom;
  final String dateTo;
  final List<ChannelSalesModel> channels;

  final double inHouseSales;
  final int inHouseInvoiceCount;

  final double thirdPartySales;
  final double thirdPartyCommission;
  final double thirdPartyNetSales;
  final int thirdPartyInvoiceCount;

  final double totalSales;
  final double totalCommission;
  final double totalNetSales;
  final int totalInvoiceCount;

  ChannelSalesReport({
    required this.dateFrom,
    required this.dateTo,
    required this.channels,
    required this.inHouseSales,
    required this.inHouseInvoiceCount,
    required this.thirdPartySales,
    required this.thirdPartyCommission,
    required this.thirdPartyNetSales,
    required this.thirdPartyInvoiceCount,
    required this.totalSales,
    required this.totalCommission,
    required this.totalNetSales,
    required this.totalInvoiceCount,
  });

  /// Channels that actually sold something — for lists that should not show
  /// six mostly-empty rows.
  List<ChannelSalesModel> get activeChannels =>
      channels.where((c) => c.invoiceCount > 0).toList();

  factory ChannelSalesReport.fromJson(Map<String, dynamic> json) {
    final inHouse = (json['in_house'] as Map<String, dynamic>?) ?? const {};
    final third = (json['third_party'] as Map<String, dynamic>?) ?? const {};
    final totals = (json['totals'] as Map<String, dynamic>?) ?? const {};

    return ChannelSalesReport(
      dateFrom: asString(json['date_from']),
      dateTo: asString(json['date_to']),
      channels: ((json['channels'] as List?) ?? [])
          .map((e) => ChannelSalesModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      inHouseSales: asDouble(inHouse['total_sales']),
      inHouseInvoiceCount: asInt(inHouse['invoice_count']),
      thirdPartySales: asDouble(third['total_sales']),
      thirdPartyCommission: asDouble(third['commission']),
      thirdPartyNetSales: asDouble(third['net_sales']),
      thirdPartyInvoiceCount: asInt(third['invoice_count']),
      totalSales: asDouble(totals['total_sales']),
      totalCommission: asDouble(totals['commission']),
      totalNetSales: asDouble(totals['net_sales']),
      totalInvoiceCount: asInt(totals['invoice_count']),
    );
  }
}
