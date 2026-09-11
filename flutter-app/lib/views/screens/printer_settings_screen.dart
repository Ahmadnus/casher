import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/app_theme.dart';
import '../../services/printer_service.dart';
import '../../services/printing/print_agent_config.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  late final PrinterService _printer;

  StreamSubscription<DiscoveredPrinter>? _scanSub;
  final List<DiscoveredPrinter> _devices = [];
  bool _loading = false;
  String _statusMessage = '';

  /// Web only: health of the local print agent.
  BackendStatus? _agentStatus;

  @override
  void initState() {
    super.initState();

    _printer = Get.isRegistered<PrinterService>()
        ? Get.find<PrinterService>()
        : Get.put(PrinterService(), permanent: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scan();
    });
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    super.dispose();
  }

  Future<void> _scan() async {
    if (!mounted) return;

    await _scanSub?.cancel();
    setState(() {
      _loading = true;
      _statusMessage = _printer.usesPrintAgent
          ? 'جاري الاتصال بوكيل الطباعة...'
          : 'جاري البحث عن طابعات سلكية...';
      _devices.clear();
    });

    if (_printer.usesPrintAgent) {
      final status = await _printer.backendStatus();
      if (!mounted) return;
      setState(() => _agentStatus = status);
      if (!status.available) {
        setState(() {
          _loading = false;
          _statusMessage = '';
        });
        return;
      }
    }

    _scanSub = _printer.discoverDevices().listen(
      (device) {
        if (!mounted) return;
        setState(() {
          if (!_devices.any((d) => d.identifier == device.identifier)) {
            _devices.add(device);
          }
        });
      },
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _statusMessage = 'خطأ أثناء البحث: $e';
        });
      },
    );

    // USB discovery is a snapshot scan, not a continuous stream — give it a
    // moment to enumerate connected devices then stop the loading spinner.
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _loading = false;
      _statusMessage = _devices.isEmpty
          ? ''
          : '';
    });
  }

  Future<void> _connectTo(
      DiscoveredPrinter device, PrinterTarget target) async {
    final label =
        target == PrinterTarget.cash ? 'طابعة الكاش' : 'طابعة الفاتورة';
    await _runWithLoading('جاري الاتصال بـ ${device.name}...', () async {
      final ok = await _printer.connectTarget(target, device);
      if (mounted) setState(() {});
      Get.snackbar(
        ok ? 'تم الاتصال ✓' : 'فشل الاتصال',
        ok
            ? 'تم تعيين ${device.name} كـ $label'
            : 'تعذر الاتصال. تأكد من توصيل الطابعة بالكابل.',
        backgroundColor: ok ? AppTheme.success : AppTheme.accent,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
    });
  }

  Future<void> _reconnect(PrinterTarget target) async {
    final label =
        target == PrinterTarget.cash ? 'طابعة الكاش' : 'طابعة الفاتورة';
    await _runWithLoading('جاري إعادة الاتصال بـ $label...', () async {
      final ok = await _printer.reconnect(target);
      if (mounted) setState(() {});
      Get.snackbar(
        ok ? 'تم الاتصال ✓' : 'فشل الاتصال',
        ok ? 'تم الاتصال بـ $label' : 'تعذر الاتصال بـ $label',
        backgroundColor: ok ? AppTheme.success : AppTheme.accent,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
    });
  }

  Future<void> _testPrint(PrinterTarget target) async {
    final label =
        target == PrinterTarget.cash ? 'طابعة الكاش' : 'طابعة الفاتورة';
    await _runWithLoading('جاري طباعة تجريبية على $label...', () async {
      final ok = await _printer.testPrint(target);
      if (mounted) setState(() {});
      Get.snackbar(
        ok ? 'تمت الطباعة ✓' : 'فشل الطباعة',
        ok ? 'تم إرسال الطباعة التجريبية إلى $label' : 'تحقق من اتصال $label',
        backgroundColor: ok ? AppTheme.success : AppTheme.accent,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
    });
  }

  Future<void> _runWithLoading(
      String message, Future<void> Function() task) async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.secondary,
        content: Row(
          children: [
            const CircularProgressIndicator(color: AppTheme.accent),
            const SizedBox(width: 16),
            Expanded(
              child: Text(message,
                  style: const TextStyle(color: AppTheme.textPrimary)),
            ),
          ],
        ),
      ),
    );

    try {
      await task();
    } catch (e) {
      if (mounted) {
        Get.snackbar(
          'خطأ',
          '$e',
          backgroundColor: AppTheme.accent,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
        );
      }
    } finally {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات الطابعات'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _scan,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (_printer.usesPrintAgent) ...[
            _AgentCard(
              status: _agentStatus,
              onChanged: _scan,
            ),
            const SizedBox(height: 10),
          ],
          if (_statusMessage.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Text(
                _statusMessage,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),

          // ── Two printer status cards ──
          _PrinterCard(
            title: 'طابعة الفاتورة',
            subtitle: 'لطباعة الفاتورة الكاملة للعميل',
            icon: Icons.receipt_long,
            connected: _printer.invoiceConnected.value,
            connectedName: _printer.invoiceConnectedName.value,
            savedName: _printer.invoiceSavedName,
            savedId: _printer.invoiceSavedId,
            onReconnect: () => _reconnect(PrinterTarget.invoice),
            onTestPrint: () => _testPrint(PrinterTarget.invoice),
          ),
          const SizedBox(height: 10),
          _PrinterCard(
            title: 'طابعة الكاش',
            subtitle: 'لطباعة إيصال داخلي / المطبخ',
            icon: Icons.point_of_sale,
            connected: _printer.cashConnected.value,
            connectedName: _printer.cashConnectedName.value,
            savedName: _printer.cashSavedName,
            savedId: _printer.cashSavedId,
            onReconnect: () => _reconnect(PrinterTarget.cash),
            onTestPrint: () => _testPrint(PrinterTarget.cash),
          ),

          const SizedBox(height: 16),
          Row(
            children: [
              Icon(_printer.usesPrintAgent ? Icons.print : Icons.usb,
                  color: AppTheme.textSecondary, size: 16),
              const SizedBox(width: 6),
              Text(
                _printer.usesPrintAgent
                    ? 'الطابعات المتاحة على هذا الجهاز'
                    : 'الطابعات السلكية المتصلة',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (_loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.accent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _buildDeviceList(),
        ],
      ),
    );
  }

  Widget _buildDeviceList() {
    if (_loading && _devices.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
      );
    }

    if (_devices.isEmpty) {
      final viaAgent = _printer.usesPrintAgent;
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(viaAgent ? Icons.print_disabled : Icons.usb_off,
                  size: 56, color: AppTheme.textSecondary),
              const SizedBox(height: 14),
              Text(
                viaAgent
                    ? (_agentStatus?.available == true
                        ? 'وكيل الطباعة لا يرى أي طابعة\n\nتأكد من تعريف الطابعة في Windows\nثم اضغط على زر التحديث.'
                        : 'وكيل الطباعة غير مشغّل\n\nشغّل CasherPrintAgent.exe على هذا الجهاز\nثم اضغط على زر التحديث.')
                    : 'لا توجد طابعات سلكية متصلة\n\nقم بتوصيل الطابعة عبر كابل USB\nثم اضغط على زر التحديث.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _devices.map((d) {
        final isCash = d.identifier == _printer.cashConnectedId.value;
        final isInvoice = d.identifier == _printer.invoiceConnectedId.value;
        return _DeviceTile(
          device: d,
          isCashActive: isCash,
          isInvoiceActive: isInvoice,
          onUseForCash: () => _connectTo(d, PrinterTarget.cash),
          onUseForInvoice: () => _connectTo(d, PrinterTarget.invoice),
        );
      }).toList(),
    );
  }
}

/// Web only: shows whether the local Casher Print Agent is reachable and
/// lets the cashier point the POS at a different address/port.
class _AgentCard extends StatefulWidget {
  final BackendStatus? status;
  final VoidCallback onChanged;

  const _AgentCard({required this.status, required this.onChanged});

  @override
  State<_AgentCard> createState() => _AgentCardState();
}

class _AgentCardState extends State<_AgentCard> {
  late final TextEditingController _url =
      TextEditingController(text: PrintAgentConfig.agentUrl);
  late final TextEditingController _token =
      TextEditingController(text: PrintAgentConfig.agentToken ?? '');

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  void _save() {
    PrintAgentConfig.agentUrl = _url.text;
    PrintAgentConfig.agentToken = _token.text.trim();
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final ok = widget.status?.available == true;
    final color = widget.status == null
        ? AppTheme.textSecondary
        : (ok ? AppTheme.success : AppTheme.accent);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ok ? Icons.cloud_done : Icons.cloud_off, color: color, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('وكيل الطباعة المحلي',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    Text(
                      widget.status == null
                          ? 'جاري الفحص...'
                          : '${widget.status!.message}'
                              '${widget.status!.version != null ? ' (v${widget.status!.version})' : ''}',
                      style: TextStyle(color: color, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!ok) ...[
            const SizedBox(height: 10),
            const Text(
              'المتصفح لا يستطيع الطباعة مباشرة على الطابعات الحرارية. '
              'شغّل برنامج CasherPrintAgent.exe الصغير على جهاز الكاشير مرة واحدة '
              '(يعمل في الخلفية ويبدأ مع Windows) ثم اضغط تحديث.',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12, height: 1.5),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _url,
                  style: const TextStyle(fontSize: 13),
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'عنوان الوكيل',
                    hintText: 'http://127.0.0.1:9123',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _token,
                  style: const TextStyle(fontSize: 13),
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'الرمز (اختياري)',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14)),
                child: const Text('حفظ'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PrinterCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool connected;
  final String connectedName;
  final String? savedName;
  final String? savedId;
  final VoidCallback onReconnect;
  final VoidCallback onTestPrint;

  const _PrinterCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.connected,
    required this.connectedName,
    required this.savedName,
    required this.savedId,
    required this.onReconnect,
    required this.onTestPrint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: connected ? AppTheme.success.withValues(alpha: 0.12) : AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: connected ? AppTheme.success.withValues(alpha: 0.4) : AppTheme.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon,
                  color: connected ? AppTheme.success : AppTheme.textSecondary,
                  size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    Text(subtitle,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              Icon(
                connected ? Icons.usb : Icons.usb_off,
                color: connected ? AppTheme.success : AppTheme.textSecondary,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  connected
                      ? 'متصل بـ $connectedName'
                      : (savedName != null
                          ? 'آخر طابعة: $savedName (غير متصل)'
                          : 'لم يتم تعيين طابعة'),
                  style: TextStyle(
                    color: connected ? AppTheme.success : AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
              if (!connected && savedId != null)
                TextButton(
                  onPressed: onReconnect,
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8)),
                  child: const Text('إعادة الاتصال',
                      style: TextStyle(color: AppTheme.accent, fontSize: 12)),
                ),
              if (connected)
                TextButton(
                  onPressed: onTestPrint,
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8)),
                  child: const Text('تجربة طباعة',
                      style:
                          TextStyle(color: AppTheme.accentGold, fontSize: 12)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final DiscoveredPrinter device;
  final bool isCashActive;
  final bool isInvoiceActive;
  final VoidCallback onUseForCash;
  final VoidCallback onUseForInvoice;

  const _DeviceTile({
    required this.device,
    required this.isCashActive,
    required this.isInvoiceActive,
    required this.onUseForCash,
    required this.onUseForInvoice,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = isCashActive || isInvoiceActive;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isActive ? AppTheme.success.withValues(alpha: 0.08) : AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? AppTheme.success.withValues(alpha: 0.5) : AppTheme.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.print,
                  color: isActive ? AppTheme.success : AppTheme.textSecondary,
                  size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.name,
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                    Text(device.identifier,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              if (isCashActive)
                _Tag(label: 'كاش', color: AppTheme.accent),
              if (isInvoiceActive)
                _Tag(label: 'فاتورة', color: AppTheme.success),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onUseForInvoice,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    side: BorderSide(
                        color: isInvoiceActive
                            ? AppTheme.success
                            : AppTheme.divider),
                  ),
                  child: Text(
                    isInvoiceActive ? '✓ طابعة الفاتورة' : 'استخدام للفاتورة',
                    style: TextStyle(
                        fontSize: 12,
                        color: isInvoiceActive
                            ? AppTheme.success
                            : AppTheme.textSecondary),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: onUseForCash,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    side: BorderSide(
                        color: isCashActive
                            ? AppTheme.accent
                            : AppTheme.divider),
                  ),
                  child: Text(
                    isCashActive ? '✓ طابعة الكاش' : 'استخدام للكاش',
                    style: TextStyle(
                        fontSize: 12,
                        color: isCashActive
                            ? AppTheme.accent
                            : AppTheme.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
