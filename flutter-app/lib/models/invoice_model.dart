import 'package:hive/hive.dart';

import '../core/json_parsing.dart';
import 'invoice_item_model.dart';
import '../services/order_type_meta.dart';

class InvoiceModel extends HiveObject {
  String id;
  int invoiceNumber;
  DateTime createdAt;
  List<InvoiceItemModel> items;
  double total;
  String? customerName;
  String? customerPhone;
  String? deliveryArea;
  String? deliveryAddress;
  /// Order source / sales channel code — see [OrderType.all] for the full
  /// list (coffee_shop, talabaty, otlob, other, …) and labels/colors.
  String orderType;
  String? tableNumber;
  String? employeeName;
  String? status;
  String? paymentMethod;
  double? subtotal;
  double? deliveryFee;
  double? tax;
  double? discount;

  /// The platform's own order id on third-party channels (Talabaty/Eshyai),
  /// printed on the ticket so staff can reconcile with the platform app.
  String? externalReference;

  /// Commission the platform took, and the total net of it. Snapshotted by
  /// the backend at issue time — zero on in-house channels.
  double? commissionAmount;
  double? netTotal;

  InvoiceModel({
    required this.id,
    required this.invoiceNumber,
    required this.createdAt,
    required this.items,
    required this.total,
    this.customerName,
    this.customerPhone,
    this.deliveryArea,
    this.deliveryAddress,
    this.orderType = 'takeaway',
    this.tableNumber,
    this.employeeName,
    this.status,
    this.paymentMethod,
    this.subtotal,
    this.deliveryFee,
    this.tax,
    this.discount,
    this.externalReference,
    this.commissionAmount,
    this.netTotal,
  });

  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);
  bool get isDelivery => orderType == 'delivery';

  /// Came through an external delivery platform rather than in-house.
  bool get isThirdParty => OrderType.isThirdParty(orderType);

  // ── API serialization ──────────────────────────────────────────
  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? [];
    final items = rawItems
        .map((e) => InvoiceItemModel.fromJson(e as Map<String, dynamic>))
        .toList();

    final invoiceNumber = _parseInvoiceNumber(json['invoice_number']);

    final employee = json['employee'] as Map<String, dynamic>?;
    final deliveryAreaMap = json['delivery_area'] as Map<String, dynamic>?;

    return InvoiceModel(
      id: json['id'].toString(),
      invoiceNumber: invoiceNumber,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      items: items,
      total: asDouble(json['total']),
      subtotal: asDoubleOrNull(json['subtotal']),
      deliveryFee: asDoubleOrNull(json['delivery_fee']),
      tax: asDoubleOrNull(json['tax']),
      discount: asDoubleOrNull(json['discount']),
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String?,
      deliveryArea: deliveryAreaMap?['name'] as String?,
      deliveryAddress: json['delivery_address'] as String?,
      orderType: json['order_type'] as String? ?? 'takeaway',
      tableNumber: json['table_number'] as String?,
      externalReference: json['external_reference'] as String?,
      commissionAmount: asDoubleOrNull(json['commission_amount']),
      netTotal: asDoubleOrNull(json['net_total']),
      employeeName: employee?['name'] as String?,
      status: json['status'] as String?,
      paymentMethod: json['payment_method'] as String?,
    );
  }

  static int _parseInvoiceNumber(dynamic raw) {
    if (raw == null) return 0;
    final str = raw.toString();
    final parts = str.split('-');
    final last = parts.last;
    return int.tryParse(last) ?? int.tryParse(str) ?? 0;
  }
}

class InvoiceModelAdapter extends TypeAdapter<InvoiceModel> {
  @override
  final int typeId = 2;

  @override
  InvoiceModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InvoiceModel(
      id: fields[0] as String,
      invoiceNumber: fields[1] as int,
      createdAt: fields[2] as DateTime,
      items: (fields[3] as List).cast<InvoiceItemModel>(),
      total: fields[4] as double,
      customerPhone: fields.containsKey(5) ? fields[5] as String? : null,
      customerName: fields.containsKey(6) ? fields[6] as String? : null,
      deliveryArea: fields.containsKey(7) ? fields[7] as String? : null,
      deliveryAddress: fields.containsKey(8) ? fields[8] as String? : null,
      orderType:
          (fields.containsKey(9) ? fields[9] as String? : null) ?? 'takeaway',
      employeeName: fields.containsKey(10) ? fields[10] as String? : null,
      tableNumber: fields.containsKey(11) ? fields[11] as String? : null,
      // Field 12 was added later — records written before it simply lack the
      // key, and containsKey keeps those older boxes readable.
      externalReference:
          fields.containsKey(12) ? fields[12] as String? : null,
    );
  }

  @override
  void write(BinaryWriter writer, InvoiceModel obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.invoiceNumber)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(3)
      ..write(obj.items)
      ..writeByte(4)
      ..write(obj.total)
      ..writeByte(5)
      ..write(obj.customerPhone)
      ..writeByte(6)
      ..write(obj.customerName)
      ..writeByte(7)
      ..write(obj.deliveryArea)
      ..writeByte(8)
      ..write(obj.deliveryAddress)
      ..writeByte(9)
      ..write(obj.orderType)
      ..writeByte(10)
      ..write(obj.employeeName)
      ..writeByte(11)
      ..write(obj.tableNumber)
      ..writeByte(12)
      ..write(obj.externalReference);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InvoiceModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
