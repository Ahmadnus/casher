import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../controllers/menu_controller.dart';
import '../../models/menu_item_model.dart';
import '../../models/category_model.dart';
import '../../platform/platform_support.dart' as platform;
import '../../services/app_theme.dart';

class MenuFormScreen extends StatefulWidget {
  final MenuItemModel? item;

  const MenuFormScreen({super.key, required this.item});

  @override
  State<MenuFormScreen> createState() => _MenuFormScreenState();
}

class _MenuFormScreenState extends State<MenuFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _isAvailable = true;
  bool _isEditing = false;
  bool _isSaving = false;
  CategoryModel? _selectedCategory;
  XFile? _pickedImage;

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _isEditing = true;
      _nameCtrl.text = widget.item!.name;
      _priceCtrl.text = widget.item!.price.toString();
      _descCtrl.text = widget.item!.description ?? '';
      _isAvailable = widget.item!.isAvailable;

      // Try to pre-select category from the loaded list
      final ctrl = Get.find<MenuItemController>();
      if (widget.item!.categoryId != null) {
        for (final cat in ctrl.categories) {
          if (cat.id == widget.item!.categoryId) {
            _selectedCategory = cat;
            break;
          }
        }
      }
      if (_selectedCategory == null && ctrl.categories.isNotEmpty) {
        for (final cat in ctrl.categories) {
          if (cat.name == widget.item!.category) {
            _selectedCategory = cat;
            break;
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      Get.snackbar('خطأ', 'يرجى اختيار فئة',
          backgroundColor: AppTheme.accent, colorText: Colors.white);
      return;
    }

    final ctrl = Get.find<MenuItemController>();
    final price = double.parse(_priceCtrl.text.trim());
    setState(() => _isSaving = true);

    bool ok;
    if (_isEditing && widget.item != null) {
      ok = await ctrl.updateMenuItem(
        widget.item!,
        {
          'name': _nameCtrl.text.trim(),
          'price': price,
          'category_id': _selectedCategory!.id,
          'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          'is_available': _isAvailable,
        },
        imagePath: _pickedImage?.path,
      );
      if (ok) {
        Get.back();
        Get.snackbar('تم', 'تم تحديث الصنف بنجاح',
            backgroundColor: AppTheme.success, colorText: Colors.white,
            snackPosition: SnackPosition.TOP);
      } else {
        Get.snackbar('خطأ', ctrl.error.value,
            backgroundColor: AppTheme.accent, colorText: Colors.white,
            snackPosition: SnackPosition.TOP);
      }
    } else {
      ok = await ctrl.addMenuItem(
        name: _nameCtrl.text.trim(),
        price: price,
        categoryId: _selectedCategory!.id,
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        isAvailable: _isAvailable,
        imagePath: _pickedImage?.path,
      );
      if (ok) {
        Get.back();
        Get.snackbar('تمت الإضافة', 'تم إضافة الصنف بنجاح',
            backgroundColor: AppTheme.success, colorText: Colors.white,
            snackPosition: SnackPosition.TOP);
      } else {
        Get.snackbar('خطأ', ctrl.error.value,
            backgroundColor: AppTheme.accent, colorText: Colors.white,
            snackPosition: SnackPosition.TOP);
      }
    }

    if (mounted) setState(() => _isSaving = false);
  }

  bool _pickingImage = false;

  Future<void> _pickImage() async {
    if (_pickingImage) return;
    _pickingImage = true;
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );
      if (file != null && mounted) setState(() => _pickedImage = file);
    } catch (_) {
    } finally {
      _pickingImage = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<MenuItemController>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'تعديل الصنف' : 'إضافة صنف جديد'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Get.back(),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: const Text('حفظ',
                style: TextStyle(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image picker — shows the newly picked photo, falling back
              // to the existing item's image when editing, or a placeholder.
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 130,
                    height: 130,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppTheme.accent.withValues(alpha: 0.4), width: 2),
                    ),
                    child: _buildImagePreview(),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text('اضغط لإضافة صورة (اختياري)',
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ),
              const SizedBox(height: 24),

              // Name
              _label('اسم الصنف *'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  hintText: 'مثال: برجر كلاسيك',
                  prefixIcon:
                      Icon(Icons.restaurant, color: AppTheme.textSecondary),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'اسم الصنف مطلوب' : null,
              ),
              const SizedBox(height: 16),

              // Price
              _label('السعر *'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _priceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                decoration: const InputDecoration(
                  hintText: '0.00',
                  prefixIcon: Icon(Icons.attach_money,
                      color: AppTheme.textSecondary),
                  suffixText: 'د.أ',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'السعر مطلوب';
                  if (double.tryParse(v) == null) return 'أدخل سعراً صحيحاً';
                  if (double.parse(v) <= 0) {
                    return 'يجب أن يكون السعر أكبر من صفر';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Category dropdown from API
              _label('الفئة *'),
              const SizedBox(height: 8),
              Obx(() {
                final cats = ctrl.categories;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<CategoryModel>(
                      value: _selectedCategory,
                      hint: const Row(children: [
                        Icon(Icons.category, color: AppTheme.textSecondary, size: 18),
                        SizedBox(width: 8),
                        Text('اختر الفئة',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 14)),
                      ]),
                      isExpanded: true,
                      dropdownColor: AppTheme.cardBg,
                      style: const TextStyle(
                          color: AppTheme.textPrimary, fontSize: 14),
                      onChanged: (v) => setState(() => _selectedCategory = v),
                      items: cats
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c.name),
                              ))
                          .toList(),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),

              // Description
              _label('الوصف (اختياري)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'وصف مختصر للصنف...',
                  alignLabelWithHint: true,
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 40),
                    child: Icon(Icons.description_outlined,
                        color: AppTheme.textSecondary),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Availability toggle
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.toggle_on_outlined,
                        color: AppTheme.textSecondary),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('متاح في القائمة',
                              style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600)),
                          Text('إيقاف لإخفاء الصنف من شاشة الطلبات',
                              style: TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isAvailable,
                      onChanged: (v) => setState(() => _isAvailable = v),
                      activeThumbColor: AppTheme.success,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(_isEditing ? Icons.save : Icons.add_circle),
                  label: Text(
                    _isEditing ? 'حفظ التعديلات' : 'إضافة الصنف',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor:
                        _isEditing ? AppTheme.accentGold : AppTheme.success,
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_pickedImage != null) {
      return platform.localImage(_pickedImage!.path, fit: BoxFit.cover);
    }
    final existingUrl = widget.item?.imageUrl;
    if (existingUrl != null && existingUrl.isNotEmpty) {
      return Image.network(
        existingUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _imagePlaceholder(),
      );
    }
    return _imagePlaceholder();
  }

  Widget _imagePlaceholder() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate_outlined,
            size: 36, color: AppTheme.accent),
        SizedBox(height: 6),
        Text('إضافة صورة',
            style: TextStyle(color: AppTheme.accent, fontSize: 12)),
      ],
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600));
}
