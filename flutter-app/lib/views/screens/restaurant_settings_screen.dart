import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/settings_controller.dart';
import '../../services/app_theme.dart';

/// Admin screen to edit restaurant identity used across the app and — most
/// visibly — printed on every receipt. Without this the receipt name falls
/// back to the DB default (config app.name), so the client could never set
/// their own business name.
class RestaurantSettingsScreen extends StatefulWidget {
  const RestaurantSettingsScreen({super.key});

  @override
  State<RestaurantSettingsScreen> createState() =>
      _RestaurantSettingsScreenState();
}

class _RestaurantSettingsScreenState extends State<RestaurantSettingsScreen> {
  final ctrl = Get.find<SettingsController>();

  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _currency;
  late final TextEditingController _footer;

  @override
  void initState() {
    super.initState();
    final s = ctrl.settings.value;
    _name = TextEditingController(text: s.name);
    _phone = TextEditingController(text: s.phone ?? '');
    _address = TextEditingController(text: s.address ?? '');
    _currency = TextEditingController(text: s.currencySymbol);
    _footer = TextEditingController(text: s.receiptFooter ?? '');
    // Refresh from server, then repopulate the fields.
    ctrl.load().then((_) {
      if (!mounted) return;
      final f = ctrl.settings.value;
      _name.text = f.name;
      _phone.text = f.phone ?? '';
      _address.text = f.address ?? '';
      _currency.text = f.currencySymbol;
      _footer.text = f.receiptFooter ?? '';
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _currency.dispose();
    _footer.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      Get.snackbar('تنبيه', 'اسم المطعم مطلوب',
          backgroundColor: AppTheme.accent,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP);
      return;
    }
    final ok = await ctrl.saveSettings({
      'name': name,
      'phone': _phone.text.trim(),
      'address': _address.text.trim(),
      'currency_symbol': _currency.text.trim().isEmpty
          ? 'د.أ'
          : _currency.text.trim(),
      'receipt_footer': _footer.text.trim(),
    });
    Get.snackbar(
      ok ? 'تم الحفظ ✓' : 'تعذر الحفظ',
      ok
          ? 'تم تحديث بيانات المطعم'
          : (ctrl.error.value.isNotEmpty
              ? ctrl.error.value
              : 'حدث خطأ، حاول مرة أخرى'),
      backgroundColor: ok ? AppTheme.success : AppTheme.accent,
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات المطعم'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Obx(() {
        if (ctrl.isLoading.value) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.accent));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field(_name, 'اسم المطعم', Icons.storefront_outlined),
            const SizedBox(height: 12),
            _field(_phone, 'رقم الهاتف', Icons.phone_outlined,
                keyboard: TextInputType.phone),
            const SizedBox(height: 12),
            _field(_address, 'العنوان', Icons.location_on_outlined,
                maxLines: 2),
            const SizedBox(height: 12),
            _field(_currency, 'رمز العملة', Icons.attach_money),
            const SizedBox(height: 12),
            _field(_footer, 'تذييل الإيصال (رسالة الشكر)',
                Icons.receipt_long_outlined,
                maxLines: 2),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: ctrl.isLoading.value ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('حفظ', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _field(TextEditingController c, String hint, IconData icon,
      {TextInputType keyboard = TextInputType.text, int maxLines = 1}) {
    return TextField(
      controller: c,
      keyboardType: keyboard,
      maxLines: maxLines,
      style: const TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: const TextStyle(color: AppTheme.textSecondary),
        prefixIcon: Icon(icon, color: AppTheme.textSecondary),
      ),
    );
  }
}
