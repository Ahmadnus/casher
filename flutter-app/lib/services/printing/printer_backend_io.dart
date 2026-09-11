import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';

import 'printer_backend.dart';

PrinterBackend createPrinterBackend() => UsbPrinterBackend();

/// Desktop / Android backend — the original USB implementation, unchanged in
/// behaviour: one live connection through the plugin, switched between the
/// cash and invoice targets by PrinterService.
class UsbPrinterBackend implements PrinterBackend {
  final PrinterManager _manager = PrinterManager.instance;

  @override
  String get displayName => Platform.isWindows ? 'طابعات النظام (USB)' : 'USB';

  @override
  bool get holdsConnection => true;

  /// Android: "vendorId:productId". Windows: the printer queue name.
  static String identifierFor(String name, String? vendorId, String? productId) =>
      Platform.isWindows ? name : '${vendorId ?? ''}:${productId ?? ''}';

  @override
  Stream<DiscoveredPrinter> discover() {
    return _manager.discovery(type: PrinterType.usb, isBle: false).map(
          (d) => DiscoveredPrinter(
            name: d.name,
            vendorId: d.vendorId,
            productId: d.productId,
            identifier: identifierFor(d.name, d.vendorId, d.productId),
          ),
        );
  }

  @override
  Future<void> connect(DiscoveredPrinter device) async {
    try {
      await _manager.disconnect(type: PrinterType.usb);
    } catch (_) {}

    final model = UsbPrinterInput(
      name: device.name,
      vendorId: device.vendorId,
      productId: device.productId,
    );
    await _manager.connect(type: PrinterType.usb, model: model);
  }

  @override
  Future<void> disconnect() async {
    try {
      await _manager.disconnect(type: PrinterType.usb);
    } catch (_) {}
  }

  @override
  Future<void> send(
    Uint8List bytes, {
    required DiscoveredPrinter device,
    String? jobName,
  }) async {
    // The plugin writes to whichever printer is currently connected;
    // PrinterService guarantees that is [device] before calling send.
    await _manager.send(type: PrinterType.usb, bytes: bytes);
  }

  @override
  Future<BackendStatus> status() async =>
      const BackendStatus(available: true, message: 'USB');
}
