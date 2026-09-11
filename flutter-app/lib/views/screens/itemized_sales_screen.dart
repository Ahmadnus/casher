import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api_exception.dart';
import '../../core/json_parsing.dart';
import '../../repositories/report_repository.dart';
import '../../services/app_theme.dart';

enum ItemizedPeriod { today, week, month, custom }

/// Itemized product sales — STRICTLY quantities, no monetary data.
/// One consolidated row per product ("شاورما: 1000") aggregated across
/// ALL paid invoices of the selected period, ordered highest first.
/// Revenue/profit tracking lives elsewhere and is deliberately absent.
///
/// Standalone page with its own named route — open from anywhere with
/// `Get.toNamed(ItemizedSalesScreen.route)`.
class ItemizedSalesScreen extends StatefulWidget {
  static const String route = '/itemized-sales';

  const ItemizedSalesScreen({super.key});

  @override
  State<ItemizedSalesScreen> createState() => _ItemizedSalesScreenState();
}

class _ItemizedSalesScreenState extends State<ItemizedSalesScreen> {
  final _repo = ReportRepository();

  ItemizedPeriod _period = ItemizedPeriod.today;
  bool _loading = true;
  String _error = '';
  int _totalItems = 0;
  List<MapEntry<String, int>> _items = const [];

  // Custom range (both default to today when the tab is first opened).
  DateTime _customFrom = DateTime.now();
  DateTime _customTo = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Inclusive date range for the active period; sent to the backend
  /// as date_from/date_to so aggregation happens in SQL over all paid
  /// invoices of that period.
  ({String from, String to}) get _range {
    final now = DateTime.now();
    switch (_period) {
      case ItemizedPeriod.today:
        return (from: _fmt(now), to: _fmt(now));
      case ItemizedPeriod.week:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        return (from: _fmt(monday), to: _fmt(now));
      case ItemizedPeriod.month:
        return (from: _fmt(DateTime(now.year, now.month, 1)), to: _fmt(now));
      case ItemizedPeriod.custom:
        return (from: _fmt(_customFrom), to: _fmt(_customTo));
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final r = _range;
      final data =
          await _repo.getItemizedReport(dateFrom: r.from, dateTo: r.to);
      // Backend returns rows already ordered by SUM(quantity) desc;
      // only name + quantity are read — monetary fields are ignored.
      final items = data['items'] as List? ?? [];
      setState(() {
        _items = items
            .map((e) => MapEntry(
                e['name'].toString(), asInt(e['total_quantity'])))
            .toList();
        _totalItems = asInt(data['total_items']);
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.displayMessage;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'فشل تحميل مبيعات الأصناف';
        _loading = false;
      });
    }
  }

  void _setPeriod(ItemizedPeriod p) {
    if (_period == p) return;
    setState(() => _period = p);
    _load();
  }

  String get _periodLabel => switch (_period) {
        ItemizedPeriod.today => DateFormat('dd/MM/yyyy').format(DateTime.now()),
        ItemizedPeriod.week => 'من ${DateFormat('dd/MM').format(DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1)))} حتى اليوم',
        ItemizedPeriod.month =>
          'شهر ${DateFormat('MM/yyyy').format(DateTime.now())}',
        ItemizedPeriod.custom =>
          'من ${DateFormat('dd/MM/yyyy').format(_customFrom)} إلى ${DateFormat('dd/MM/yyyy').format(_customTo)}',
      };

  /// Opens a calendar for one end of the custom range, then re-queries
  /// the backend immediately with the new date_from/date_to.
  Future<void> _pickCustomDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _customFrom : _customTo,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _customFrom = picked;
        if (_customTo.isBefore(_customFrom)) _customTo = _customFrom;
      } else {
        _customTo = picked;
        if (_customTo.isBefore(_customFrom)) _customFrom = _customTo;
      }
      _period = ItemizedPeriod.custom;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.inventory_2,
                  color: AppTheme.success, size: 22),
            ),
            const SizedBox(width: 10),
            const Text('مبيعات الأصناف بالكمية'),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          // ── Period tabs ──
          Container(
            color: AppTheme.secondary,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                _PeriodTab(
                    label: 'اليوم',
                    selected: _period == ItemizedPeriod.today,
                    onTap: () => _setPeriod(ItemizedPeriod.today)),
                const SizedBox(width: 6),
                _PeriodTab(
                    label: 'هذا الأسبوع',
                    selected: _period == ItemizedPeriod.week,
                    onTap: () => _setPeriod(ItemizedPeriod.week)),
                const SizedBox(width: 6),
                _PeriodTab(
                    label: 'هذا الشهر',
                    selected: _period == ItemizedPeriod.month,
                    onTap: () => _setPeriod(ItemizedPeriod.month)),
                const SizedBox(width: 6),
                _PeriodTab(
                    label: 'مخصص',
                    selected: _period == ItemizedPeriod.custom,
                    onTap: () => _setPeriod(ItemizedPeriod.custom)),
              ],
            ),
          ),
          // ── Custom From/To pickers ──
          if (_period == ItemizedPeriod.custom)
            Container(
              color: AppTheme.secondary,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _DateField(
                        label: 'من',
                        value: DateFormat('dd/MM/yyyy').format(_customFrom),
                        onTap: () => _pickCustomDate(isFrom: true)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DateField(
                        label: 'إلى',
                        value: DateFormat('dd/MM/yyyy').format(_customTo),
                        onTap: () => _pickCustomDate(isFrom: false)),
                  ),
                ],
              ),
            ),
          // ── Summary header (counts only — no currency) ──
          Container(
            width: double.infinity,
            color: AppTheme.secondary,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.date_range,
                    size: 15, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Text(_periodLabel,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13)),
                const Spacer(),
                Text('إجمالي القطع: $_totalItems',
                    style: const TextStyle(
                        color: AppTheme.success,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                    ? Center(
                        child: Text(_error,
                            style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 15)))
                    : _items.isEmpty
                        ? const Center(
                            child: Text('لا مبيعات مسجلة في هذه الفترة',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 16)))
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _items.length,
                            itemBuilder: (_, i) => _ItemRow(
                                rank: i + 1,
                                name: _items[i].key,
                                quantity: _items[i].value),
                          ),
          ),
        ],
      ),
    );
  }
}

/// Tappable "من / إلى" date chip that opens the calendar picker.
class _DateField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const _DateField(
      {required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            Text('$label: ',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12)),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
            const Icon(Icons.calendar_today,
                size: 15, color: AppTheme.success),
          ],
        ),
      ),
    );
  }
}

class _PeriodTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PeriodTab(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppTheme.success : AppTheme.cardBg,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? Colors.white : AppTheme.textSecondary,
                fontSize: 13,
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal,
              )),
        ),
      ),
    );
  }
}

/// One consolidated product row: rank, name, total quantity — nothing else.
class _ItemRow extends StatelessWidget {
  final int rank;
  final String name;
  final int quantity;
  const _ItemRow(
      {required this.rank, required this.name, required this.quantity});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Center(
              child: Text('$rank',
                  style: const TextStyle(
                      color: AppTheme.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name,
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 15)),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('$quantity',
                style: const TextStyle(
                    color: AppTheme.success,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
