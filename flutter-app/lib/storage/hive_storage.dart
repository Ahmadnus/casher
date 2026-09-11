import 'package:hive_flutter/hive_flutter.dart';
import '../models/menu_item_model.dart';
import '../models/invoice_model.dart';
import '../models/invoice_item_model.dart';
import '../models/delivery_area_model.dart';
import '../models/employee_model.dart';

class HiveStorage {
  // ── Box names ──────────────────────────────────────────────────
  static const String menuBox = 'menuBox';
  static const String invoicesBox = 'invoicesBox';
  static const String settingsBox = 'settingsBox';     // auth token lives here
  static const String deliveryAreasBox = 'deliveryAreasBox';
  static const String employeesBox = 'employeesBox';
  static const String sessionBox = 'sessionBox';
  static const String printerSettingsBox = 'printerSettingsBox'; // BT addresses

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(MenuItemModelAdapter());
    Hive.registerAdapter(InvoiceItemModelAdapter());
    Hive.registerAdapter(InvoiceModelAdapter());
    Hive.registerAdapter(DeliveryAreaModelAdapter());
    Hive.registerAdapter(EmployeeModelAdapter());

    await _safeOpenInvoiceBox();

    await Hive.openBox<MenuItemModel>(menuBox);
    await Hive.openBox(settingsBox);
    await Hive.openBox<DeliveryAreaModel>(deliveryAreasBox);
    await Hive.openBox<EmployeeModel>(employeesBox);
    await Hive.openBox(sessionBox);
    await Hive.openBox(printerSettingsBox);
  }

  static Future<void> _safeOpenInvoiceBox() async {
    try {
      final box = await Hive.openBox<InvoiceModel>(invoicesBox);
      // Touch each field to trigger a schema-read error early
      for (final inv in box.values) {
        // ignore: unused_local_variable
        final _ = inv.orderType;
      }
      await box.close();
    } catch (_) {
      await Hive.deleteBoxFromDisk(invoicesBox);
    }
    await Hive.openBox<InvoiceModel>(invoicesBox);
  }

  // ── Box accessors ──────────────────────────────────────────────
  static Box<MenuItemModel> get menu => Hive.box<MenuItemModel>(menuBox);
  static Box<InvoiceModel> get invoices => Hive.box<InvoiceModel>(invoicesBox);
  static Box get settings => Hive.box(settingsBox);
  static Box<DeliveryAreaModel> get deliveryAreas =>
      Hive.box<DeliveryAreaModel>(deliveryAreasBox);
  static Box<EmployeeModel> get employees =>
      Hive.box<EmployeeModel>(employeesBox);
  static Box get session => Hive.box(sessionBox);
  static Box get printerSettings => Hive.box(printerSettingsBox);
}
