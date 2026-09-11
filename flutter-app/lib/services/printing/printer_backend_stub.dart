import 'dart:typed_data';

import 'printer_backend.dart';

PrinterBackend createPrinterBackend() => _NoPrinterBackend();

/// Compile-time fallback for platforms with neither dart:io nor dart:html.
class _NoPrinterBackend implements PrinterBackend {
  @override
  String get displayName => 'غير مدعوم';

  @override
  bool get holdsConnection => false;

  @override
  Stream<DiscoveredPrinter> discover() => const Stream.empty();

  @override
  Future<void> connect(DiscoveredPrinter device) async =>
      throw UnsupportedError('printing not supported');

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> send(Uint8List bytes,
          {required DiscoveredPrinter device, String? jobName}) async =>
      throw UnsupportedError('printing not supported');

  @override
  Future<BackendStatus> status() async =>
      const BackendStatus(available: false, message: 'الطباعة غير مدعومة');
}
