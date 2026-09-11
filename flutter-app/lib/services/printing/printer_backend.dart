import 'dart:typed_data';

/// A printer known to this device.
///
/// Desktop/Windows: a queue registered in the OS print spooler (identified by
/// its name). Android: a USB-OTG device (vendorId:productId). Web: a spooler
/// queue reported by the local print agent (identified by its name).
class DiscoveredPrinter {
  final String name;
  final String? vendorId;
  final String? productId;

  /// Stable string stored in Hive as `device_identifier`.
  final String identifier;

  const DiscoveredPrinter({
    required this.name,
    required this.identifier,
    this.vendorId,
    this.productId,
  });
}

/// Where print jobs actually go. The platform decides which one is compiled
/// in (see printer_backend_factory.dart):
///
///   desktop / android  → USB plugin (flutter_pos_printer_platform_image_3)
///   web                → local print agent over http://127.0.0.1:9123
///
/// PrinterService only talks to this interface, so the screens, the receipt
/// bytes and the two-printer (cash / invoice) configuration are shared.
abstract class PrinterBackend {
  /// Human-readable name shown in the printer settings screen.
  String get displayName;

  /// True when the backend keeps one live connection that must be switched
  /// between targets (USB plugin). False when every job is addressed to a
  /// printer by name and no connection state exists (print agent).
  bool get holdsConnection;

  /// Enumerate printers available right now.
  Stream<DiscoveredPrinter> discover();

  /// Open the live connection (USB) or verify the printer exists (agent).
  Future<void> connect(DiscoveredPrinter device);

  Future<void> disconnect();

  /// Send raw ESC/POS bytes to [device].
  Future<void> send(
    Uint8List bytes, {
    required DiscoveredPrinter device,
    String? jobName,
  });

  /// Backend health, e.g. whether the print agent is reachable.
  Future<BackendStatus> status();
}

class BackendStatus {
  final bool available;
  final String message;
  final String? version;

  const BackendStatus({
    required this.available,
    required this.message,
    this.version,
  });
}
