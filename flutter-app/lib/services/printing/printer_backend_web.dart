import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'print_agent_config.dart';
import 'printer_backend.dart';

PrinterBackend createPrinterBackend() => AgentPrinterBackend();

/// Web backend — talks to the Casher Print Agent, a tiny local service the
/// customer installs once on the POS computer (tools/print-agent in the
/// backend repo). The browser cannot open USB devices, but it CAN call
/// http://127.0.0.1, and the agent forwards the raw ESC/POS bytes to the
/// Windows print spooler exactly like the desktop plugin does.
///
///   Flutter Web ──HTTP──▶ CasherPrintAgent ──RAW──▶ thermal printer
///
/// Any number of printers is supported: every job names its target queue,
/// so there is no "one live connection" limitation here.
class AgentPrinterBackend implements PrinterBackend {
  static String get agentUrl => PrintAgentConfig.agentUrl;
  static String? get agentToken => PrintAgentConfig.agentToken;

  // Dedicated client: the API's auth interceptor must not run against the
  // agent, and the agent must never see the POS token.
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 3),
    receiveTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 15),
    responseType: ResponseType.json,
  ));

  Map<String, String> get _headers => {
        'X-Agent-Token': ?agentToken,
      };

  @override
  String get displayName => 'وكيل الطباعة المحلي';

  @override
  bool get holdsConnection => false;

  @override
  Stream<DiscoveredPrinter> discover() async* {
    final res = await _dio.get('$agentUrl/printers',
        options: Options(headers: _headers));
    final list = (res.data as Map)['printers'] as List? ?? [];
    for (final p in list) {
      final name = (p as Map)['name'].toString();
      yield DiscoveredPrinter(name: name, identifier: name);
    }
  }

  @override
  Future<void> connect(DiscoveredPrinter device) async {
    // No connection to hold — just make sure the queue exists right now so
    // the settings screen reports a real "connected" state.
    final printers = await discover().toList();
    if (!printers.any((p) => p.identifier == device.identifier)) {
      throw StateError('الطابعة "${device.name}" غير موجودة على هذا الجهاز');
    }
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> send(
    Uint8List bytes, {
    required DiscoveredPrinter device,
    String? jobName,
  }) async {
    final res = await _dio.post(
      '$agentUrl/print',
      data: jsonEncode({
        'printer': device.name,
        'data': base64Encode(bytes),
        'job_name': ?jobName,
      }),
      options: Options(
        headers: {'Content-Type': 'application/json', ..._headers},
      ),
    );
    final body = res.data;
    if (body is Map && body['ok'] != true) {
      throw StateError(body['error']?.toString() ?? 'فشلت الطباعة');
    }
  }

  @override
  Future<BackendStatus> status() async {
    try {
      final res = await _dio.get('$agentUrl/health');
      final data = res.data as Map;
      return BackendStatus(
        available: data['ok'] == true,
        message: 'متصل بوكيل الطباعة على $agentUrl',
        version: data['version']?.toString(),
      );
    } on DioException catch (e) {
      final why = e.response?.statusCode == 401
          ? 'رمز وكيل الطباعة غير صحيح'
          : 'وكيل الطباعة غير مشغّل على هذا الجهاز';
      return BackendStatus(available: false, message: why);
    } catch (_) {
      return const BackendStatus(
          available: false, message: 'تعذر الوصول إلى وكيل الطباعة');
    }
  }
}
