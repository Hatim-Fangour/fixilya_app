import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/features/marketplace/data/models/product_model.dart';
import 'package:fixilya_app/features/marketplace/presentation/controllers/marketplace_controller.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';

/// Horizontally scrollable category filter chip bar.
/// Shows an icon + label for each [ProductCategory]. Selected chip uses a
/// primary-colour gradient; unselected chips use a subtle surface card style.
class CategoryChips extends StatelessWidget {
  const CategoryChips({super.key});

  static const _primaryColor   = Color.fromRGBO(83, 110, 254, 1);
  static const _secondaryColor = Color.fromRGBO(123, 144, 250, 1);

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MarketplaceController>();

    return SizedBox(
      height: 42,
      child: Obx(() {
        // ⚠️ IMPORTANT: read .obs HERE, inside the Obx builder body.
        // GetX tracks observable access only during this function's execution.
        // If we read it inside itemBuilder (called lazily by ListView), GetX
        // never registers the dependency and throws "improper use of Obx".
        final selectedCategory = controller.selectedCategory.value;

        return ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: ProductCategory.values.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final category   = ProductCategory.values[index];
            final isSelected = selectedCategory == category; // local var, no .obs read here

            return GestureDetector(
              onTap: () => controller.setCategory(category),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(colors: [_primaryColor, _secondaryColor])
                      : null,
                  color: isSelected ? null : AppColors.cardColor(context),
                  borderRadius: BorderRadius.circular(21),
                  border: isSelected
                      ? null
                      : Border.all(color: AppColors.borderColor(context), width: 1),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: _primaryColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FaIcon(
                      _iconFor(category),
                      size: 12,
                      color: isSelected ? Colors.white : Colors.grey[600],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      category.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : Colors.grey[700],
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
        // ^ semicolon ends the return statement inside the block function
      }),
    );
  }

  IconData _iconFor(ProductCategory category) {
    switch (category) {
      case ProductCategory.all:        return FontAwesomeIcons.store;
      case ProductCategory.materials:  return FontAwesomeIcons.layerGroup;
      case ProductCategory.tools:      return FontAwesomeIcons.screwdriverWrench;
      case ProductCategory.pharmacy:   return FontAwesomeIcons.kitMedical;
      case ProductCategory.electrical: return FontAwesomeIcons.bolt;
      case ProductCategory.plumbing:   return FontAwesomeIcons.droplet;
      case ProductCategory.paint:      return FontAwesomeIcons.paintRoller;
      case ProductCategory.cleaning:   return FontAwesomeIcons.broom;
    }
  }
}
