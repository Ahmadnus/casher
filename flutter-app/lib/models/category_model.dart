import '../core/json_parsing.dart';

class CategoryModel {
  final int id;
  final String name;
  final String slug;
  final String? imageUrl;
  final bool isActive;
  final int sortOrder;
  final int? menuItemsCount;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    this.imageUrl,
    this.isActive = true,
    this.sortOrder = 0,
    this.menuItemsCount,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: asInt(json['id']),
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      isActive: asBool(json['is_active'], true),
      sortOrder: asInt(json['sort_order']),
      menuItemsCount: asIntOrNull(json['menu_items_count']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'image_url': imageUrl,
        'is_active': isActive,
        'sort_order': sortOrder,
        'menu_items_count': menuItemsCount,
      };
}
