import 'dart:async';
import 'dart:typed_data';

import 'package:get/get.dart';

import '../controllers/settings_controller.dart';
import '../models/invoice_model.dart';
import '../models/settings_model.dart';
import '../platform/platform_support.dart' as platform;
import '../storage/hive_storage.dart';
import 'printing/printer_backend.dart';
import 'printing/printer_backend_factory.dart';
import 'printing/receipt_builder.dart';
import 'printing/receipt_html.dart';

export 'printing/printer_backend.dart' show DiscoveredPrinter, BackendStatus;

enum PrinterTarget { cash, invoice }

/// Two printer slots — cash/kitchen slip and customer invoice — persisted in
/// Hive and printed through whichever [PrinterBackend] the platform provides:
///
///   desktop / android : USB plugin. The plugin holds ONE live connection, so
///                       this service switches it to whichever target is
///                       printing (transparent: "print invoice" connects the
///                       invoice printer, "print cash slip" the cash printer).
///   web               : local print agent. Every job names its printer; no
///                       connection switching is needed and any number of
///                       printers can be configured.
///
/// Receipt bytes come from [ReceiptBuilder] and are identical on every platform.
class PrinterService extends GetxService {
  static const _cashIdKey = 'cashPrinterIdentifier';
  static const _cashNameKey = 'cashPrinterName';
  static const _invIdKey = 'invoicePrinterIdentifier';
  static const _invNameKey = 'invoicePrinterName';

  final PrinterBackend _backend = createPrinterBackend();

  final RxBool cashConnected = false.obs;
  final RxString cashConnectedName = ''.obs;
  final RxString cashConnectedId = ''.obs;

  final RxBool invoiceConnected = false.obs;
  final RxString invoiceConnectedName = ''.obs;
  final RxString invoiceConnectedId = ''.obs;

  PrinterTarget? _activeTarget;

  /// True on web, where printing goes through the local agent.
  bool get usesPrintAgent => !_backend.holdsConnection;

  String get backendName => _backend.displayName;

  Future<BackendStatus> backendStatus() => _backend.status();

  // ── Saved printer getters ──────────────────────
  String? get cashSavedId =>
      HiveStorage.printerSettings.get(_cashIdKey) as String?;
  String? get cashSavedName =>
      HiveStorage.printerSettings.get(_cashNameKey) as String?;
  String? get invoiceSavedId =>
      HiveStorage.printerSettings.get(_invIdKey) as String?;
  String? get invoiceSavedName =>
      HiveStorage.printerSettings.get(_invNameKey) as String?;

  void _saveCash(String id, String name) {
    try {
      HiveStorage.printerSettings.put(_cashIdKey, id);
      HiveStorage.printerSettings.put(_cashNameKey, name);
    } catch (_) {}
  }

  void _saveInvoice(String id, String name) {
    try {
      HiveStorage.printerSettings.put(_invIdKey, id);
      HiveStorage.printerSettings.put(_invNameKey, name);
    } catch (_) {}
  }

  /// Forget the saved printer for [target].
  void clearTarget(PrinterTarget target) {
    try {
      if (target == PrinterTarget.cash) {
        HiveStorage.printerSettings.delete(_cashIdKey);
        HiveStorage.printerSettings.delete(_cashNameKey);
        cashConnected.value = false;
        cashConnectedId.value = '';
        cashConnectedName.value = '';
      } else {
        HiveStorage.printerSettings.delete(_invIdKey);
        HiveStorage.printerSettings.delete(_invNameKey);
        invoiceConnected.value = false;
        invoiceConnectedId.value = '';
        invoiceConnectedName.value = '';
      }
    } catch (_) {}
  }

  DiscoveredPrinter? _savedDevice(PrinterTarget target) {
    final id = target == PrinterTarget.cash ? cashSavedId : invoiceSavedId;
    if (id == null || id.isEmpty) return null;
    final name =
        (target == PrinterTarget.cash ? cashSavedName : invoiceSavedName) ?? id;
    return DiscoveredPrinter(name: name, identifier: id);
  }

  // ── Discovery ───────────────────────────────────
  /// Scans for printers. Desktop: spooler queues / USB devices. Web: queues
  /// reported by the local print agent.
  Stream<DiscoveredPrinter> discoverDevices() => _backend.discover();

  // ── Connect to a specific printer target ───────
  Future<bool> connectTarget(
      PrinterTarget target, DiscoveredPrinter device) async {
    try {
      await _backend.connect(device);
      final id = device.identifier;

      _activeTarget = target;
      if (target == PrinterTarget.cash) {
        cashConnected.value = true;
        cashConnectedId.value = id;
        cashConnectedName.value = device.name;
        // A single USB connection can only be held by one target at a time.
        if (_backend.holdsConnection) invoiceConnected.value = false;
        _saveCash(id, device.name);
      } else {
        invoiceConnected.value = true;
        invoiceConnectedId.value = id;
        invoiceConnectedName.value = device.name;
        if (_backend.holdsConnection) cashConnected.value = false;
        _saveInvoice(id, device.name);
      }
      return true;
    } catch (_) {
      if (target == PrinterTarget.cash) {
        cashConnected.value = false;
      } else {
        invoiceConnected.value = false;
      }
      return false;
    }
  }

  Future<void> disconnect() async {
    await _backend.disconnect();
    cashConnected.value = false;
    invoiceConnected.value = false;
    _activeTarget = null;
  }

  /// Re-scans and reconnects to the last-saved device for [target] by
  /// matching its stored identifier against currently available printers.
  Future<bool> reconnect(PrinterTarget target) async {
    final saved = _savedDevice(target);
    if (saved == null) return false;

    final found = Completer<DiscoveredPrinter?>();
    late final StreamSubscription sub;
    sub = discoverDevices().listen(
      (d) {
        if (d.identifier == saved.identifier && !found.isCompleted) {
          found.complete(d);
        }
      },
      onError: (_) {
        if (!found.isCompleted) found.complete(null);
      },
      onDone: () {
        if (!found.isCompleted) found.complete(null);
      },
    );

    final device = await found.future.timeout(
      const Duration(seconds: 4),
      onTimeout: () => null,
    );
    await sub.cancel();

    // Fall back to a synthetic device built from saved data — works on
    // Windows (and the agent) where the queue name alone is enough.
    return connectTarget(target, device ?? saved);
  }

  Future<bool> _ensureActive(PrinterTarget target) async {
    if (!_backend.holdsConnection) {
      // Agent: nothing to connect; a saved printer is all we need.
      return _savedDevice(target) != null;
    }
    final alreadyActive = _activeTarget == target &&
        (target == PrinterTarget.cash
            ? cashConnected.value
            : invoiceConnected.value);
    if (alreadyActive) return true;
    return reconnect(target);
  }

  Future<bool> _sendTo(PrinterTarget target, Uint8List bytes, String job) async {
    try {
      final ok = await _ensureActive(target);
      if (!ok) return false;
      final device = _savedDevice(target);
      if (device == null) return false;
      await _backend.send(bytes, device: device, jobName: job);
      if (!_backend.holdsConnection) {
        // Reflect a successful agent job as "connected" in the UI.
        if (target == PrinterTarget.cash) {
          cashConnected.value = true;
          cashConnectedId.value = device.identifier;
          cashConnectedName.value = device.name;
        } else {
          invoiceConnected.value = true;
          invoiceConnectedId.value = device.identifier;
          invoiceConnectedName.value = device.name;
        }
      }
      return true;
    } catch (_) {
      if (target == PrinterTarget.cash) {
        cashConnected.value = false;
      } else {
        invoiceConnected.value = false;
      }
      return false;
    }
  }

  // ── Print invoice (full) ───────────────────────
  Future<bool> printInvoice(InvoiceModel invoice) => _sendTo(
        PrinterTarget.invoice,
        _builder.invoice(invoice),
        'Invoice #${invoice.invoiceNumber}',
      );

  // ── Print cash / kitchen slip (short) ──────────
  Future<bool> printCashSlip(InvoiceModel invoice) => _sendTo(
        PrinterTarget.cash,
        _builder.cashSlip(invoice),
        'Kitchen #${invoice.invoiceNumber}',
      );

  // ── Test print for a given target ──────────────
  Future<bool> testPrint(PrinterTarget target) {
    final label =
        target == PrinterTarget.cash ? 'طابعة الكاش' : 'طابعة الفاتورة';
    return _sendTo(target, _builder.test(label), 'Test print');
  }

  // ── Browser print fallback (web only) ──────────
  /// True when the platform can open the browser's print dialog.
  bool get supportsBrowserPrint => platform.isWebPlatform;

  /// Opens the receipt in a browser print dialog. Fallback for web
  /// installs without the print agent; always returns false on desktop.
  Future<bool> printInvoiceInBrowser(InvoiceModel invoice,
      {bool prices = true}) {
    final html = ReceiptHtml(settings: _settingsModel).invoice(invoice,
        prices: prices);
    return platform.openPrintWindow(html,
        title: 'فاتورة #${invoice.invoiceNumber}');
  }

  ReceiptBuilder get _builder => ReceiptBuilder(settings: _settingsModel);

  /// Current restaurant settings (name/address/phone/footer) for receipts.
  SettingsModel? get _settingsModel {
    try {
      if (Get.isRegistered<SettingsController>()) {
        return Get.find<SettingsController>().settings.value;
      }
    } catch (_) {}
    return null;
  }
}
