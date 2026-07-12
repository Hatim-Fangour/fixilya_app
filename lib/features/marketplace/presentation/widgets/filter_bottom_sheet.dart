import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/features/marketplace/data/models/product_model.dart';
import 'package:fixilya_app/features/marketplace/presentation/controllers/marketplace_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Full-height filter bottom sheet.
/// Contains: category selector, price range slider, sort options.
/// All changes are applied immediately (reactive controller). Tapping "Apply"
/// dismisses the sheet; "Reset" clears all filters first.
void showFilterBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _FilterSheet(),
  );
}

class _FilterSheet extends StatelessWidget {
  const _FilterSheet();

  static const _primaryColor = Color.fromRGBO(83, 110, 254, 1);

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MarketplaceController>();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceColor(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimaryColor(context),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => controller.resetFilters(),
                      child: const Text(
                        'Reset All',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Category ──────────────────────────────────────────
                      _sectionLabel('Category', context),
                      const SizedBox(height: 12),
                      _CategorySelector(controller: controller),
                      const SizedBox(height: 24),

                      // ── Price range ───────────────────────────────────────
                      _sectionLabel('Price Range', context),
                      const SizedBox(height: 4),
                      _PriceRangeSlider(controller: controller),
                      const SizedBox(height: 24),

                      // ── Sort by ───────────────────────────────────────────
                      _sectionLabel('Sort By', context),
                      const SizedBox(height: 12),
                      _SortSelector(controller: controller),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // Apply button
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_primaryColor, Color.fromRGBO(123, 144, 250, 1)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: _primaryColor.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Obx(
                          () => Text(
                            'Show ${controller.displayedProducts.length} results',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionLabel(String text, BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimaryColor(context),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _CategorySelector extends StatelessWidget {
  final MarketplaceController controller;
  const _CategorySelector({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: ProductCategory.values.map((cat) {
          final selected = controller.selectedCategory.value == cat;
          return ChoiceChip(
            label: Text(cat.label),
            selected: selected,
            onSelected: (_) => controller.setCategory(cat),
            selectedColor: const Color.fromRGBO(83, 110, 254, 1),
            labelStyle: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondaryColor(context),
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
            backgroundColor: AppColors.cardColor(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: selected
                    ? Colors.transparent
                    : AppColors.borderColor(context),
              ),
            ),
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          );
        }).toList(),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PriceRangeSlider extends StatelessWidget {
  final MarketplaceController controller;
  const _PriceRangeSlider({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final range = controller.priceRange.value;
      final max   = controller.maxPrice.value;

      return Column(
        children: [
          // Current range label
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _priceChip('${range.start.round()} MAD', context),
              _priceChip('${range.end.round()} MAD', context),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color.fromRGBO(83, 110, 254, 1),
              inactiveTrackColor:
                  const Color.fromRGBO(83, 110, 254, 1).withValues(alpha: 0.2),
              thumbColor: const Color.fromRGBO(83, 110, 254, 1),
              overlayColor:
                  const Color.fromRGBO(83, 110, 254, 1).withValues(alpha: 0.15),
              trackHeight: 4,
            ),
            child: RangeSlider(
              values: range,
              min: 0,
              max: max,
              divisions: (max / 50).round().clamp(1, 200),
              onChanged: controller.setPriceRange,
            ),
          ),
        ],
      );
    });
  }

  Widget _priceChip(String text, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderColor(context)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color.fromRGBO(83, 110, 254, 1),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SortSelector extends StatelessWidget {
  final MarketplaceController controller;
  const _SortSelector({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Column(
        children: SortOption.values.map((option) {
          final selected = controller.sortBy.value == option;
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? const Color.fromRGBO(83, 110, 254, 1)
                      : Colors.grey[400]!,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Center(
                      child: CircleAvatar(
                        radius: 5,
                        backgroundColor: Color.fromRGBO(83, 110, 254, 1),
                      ),
                    )
                  : null,
            ),
            title: Text(
              option.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected
                    ? const Color.fromRGBO(83, 110, 254, 1)
                    : AppColors.textSecondaryColor(context),
              ),
            ),
            onTap: () => controller.setSort(option),
          );
        }).toList(),
      );
    });
  }
}
