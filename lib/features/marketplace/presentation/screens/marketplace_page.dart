import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/features/marketplace/data/models/product_model.dart';
import 'package:fixilya_app/features/marketplace/presentation/controllers/marketplace_controller.dart';
import 'package:fixilya_app/features/marketplace/presentation/widgets/category_chips.dart';
import 'package:fixilya_app/features/marketplace/presentation/widgets/filter_bottom_sheet.dart';
import 'package:fixilya_app/features/marketplace/presentation/widgets/product_card.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';

class MarketplacePage extends GetView<MarketplaceController> {
  const MarketplacePage({super.key});

  static const _primaryColor   = Color.fromRGBO(83, 110, 254, 1);
  static const _secondaryColor = Color.fromRGBO(123, 144, 250, 1);

  // ── Lazy-registers the controller the first time the page is shown ──────
  // Using Get.lazyPut or Get.put here ensures the controller exists even if
  // WidgetTree doesn't pre-register it in a Binding.
  static void register() {
    if (!Get.isRegistered<MarketplaceController>()) {
      // permanent: true — the marketplace tab lives inside IndexedStack for the
      // entire session. Marking permanent prevents GetX's SmartManagement from
      // disposing the controller when a child route (e.g. ProductDetailPage) is
      // pushed on top, which would break Get.find<MarketplaceController>() calls
      // from within that child page.
      Get.put(MarketplaceController(), permanent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ensure controller is registered before building
    MarketplacePage.register();

    return Scaffold(
      backgroundColor: AppColors.backgroundColor(context),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // ── Search + cart header ───────────────────────────────────────
            _SearchHeader(controller: controller),
            const SizedBox(height: 8),

            // ── Category chips ────────────────────────────────────────────
            const CategoryChips(),
            const SizedBox(height: 8),

            // ── Sort / filter bar ─────────────────────────────────────────
            _SortFilterBar(controller: controller),
            const SizedBox(height: 4),

            // ── Product grid ──────────────────────────────────────────────
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const _LoadingGrid();
                }

                if (controller.displayedProducts.isEmpty) {
                  return _EmptyState(
                    onReset: controller.resetFilters,
                  );
                }

                return RefreshIndicator(
                  color: _primaryColor,
                  onRefresh: controller.loadProducts,
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      // Fixed height prevents overflow regardless of screen width.
                      // childAspectRatio is intentionally omitted — mainAxisExtent
                      // takes precedence and gives a predictable card height.
                      mainAxisExtent: 280,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: controller.displayedProducts.length,
                    itemBuilder: (context, index) {
                      return ProductCard(
                        product: controller.displayedProducts[index],
                      );
                    },
                  ),
                );
              }),
            ),
          ],
        ),
      ),

      // ── Floating cart button ──────────────────────────────────────────────
      floatingActionButton: Obx(() {
        final count = controller.cartItemCount;
        if (count == 0) return const SizedBox.shrink();
        return FloatingActionButton.extended(
          onPressed: () => _showCartSheet(context),
          backgroundColor: _primaryColor,
          elevation: 6,
          icon: const Icon(Icons.shopping_cart, color: Colors.white, size: 20),
          label: Text(
            '$count item${count == 1 ? '' : 's'} — '
            '${controller.cartTotal.toStringAsFixed(0)} MAD',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        );
      }),
    );
  }

  // ─── Cart bottom sheet ─────────────────────────────────────────────────────
  void _showCartSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CartSheet(controller: controller),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search + Cart header
// ─────────────────────────────────────────────────────────────────────────────

class _SearchHeader extends StatefulWidget {
  final MarketplaceController controller;
  const _SearchHeader({required this.controller});

  @override
  State<_SearchHeader> createState() => _SearchHeaderState();
}

class _SearchHeaderState extends State<_SearchHeader> {
  final _searchCtrl = TextEditingController();

  static const _primaryColor = Color.fromRGBO(83, 110, 254, 1);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          // Search field
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.cardColor(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderColor(context)),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: widget.controller.setSearch,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimaryColor(context),
                ),
                decoration: InputDecoration(
                  hintText: 'Search products, tools, materials…',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondaryColor(context),
                  ),
                  prefixIcon: Icon(Icons.search, size: 18,
                      color: AppColors.textSecondaryColor(context)),
                  suffixIcon: Obx(() {
                    if (widget.controller.searchQuery.value.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return GestureDetector(
                      onTap: () {
                        _searchCtrl.clear();
                        widget.controller.setSearch('');
                      },
                      child: Icon(Icons.close, size: 16,
                          color: AppColors.textSecondaryColor(context)),
                    );
                  }),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Filter button
          GestureDetector(
            onTap: () => showFilterBottomSheet(context),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color.fromRGBO(83, 110, 254, 1),
                    Color.fromRGBO(123, 144, 250, 1),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.tune, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sort / results count bar
// ─────────────────────────────────────────────────────────────────────────────

class _SortFilterBar extends StatelessWidget {
  final MarketplaceController controller;
  const _SortFilterBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Obx(() {
        final count = controller.displayedProducts.length;
        final sort  = controller.sortBy.value;

        return Row(
          children: [
            Text(
              '$count product${count == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryColor(context),
              ),
            ),
            const Spacer(),
            // Sort dropdown
            GestureDetector(
              onTap: () => _showSortMenu(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.cardColor(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderColor(context)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const FaIcon(FontAwesomeIcons.arrowDownWideShort,
                        size: 12, color: Color.fromRGBO(83, 110, 254, 1)),
                    const SizedBox(width: 6),
                    Text(
                      sort.label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color.fromRGBO(83, 110, 254, 1),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down,
                        size: 14, color: Color.fromRGBO(83, 110, 254, 1)),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  void _showSortMenu(BuildContext context) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset offset = box.localToGlobal(Offset.zero);

    showMenu<SortOption>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx + box.size.width - 200,
        offset.dy + box.size.height + 8,
        offset.dx + box.size.width,
        0,
      ),
      items: SortOption.values
          .map(
            (opt) => PopupMenuItem<SortOption>(
              value: opt,
              child: Text(opt.label,
                  style: const TextStyle(fontSize: 13)),
            ),
          )
          .toList(),
    ).then((selected) {
      if (selected != null) controller.setSort(selected);
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton loading grid
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingGrid extends StatelessWidget {
  const _LoadingGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 280,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 8,
      itemBuilder: (_, __) => _SkeletonCard(),
    );
  }
}

class _SkeletonCard extends StatefulWidget {
  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardColor(context),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                aspectRatio: 1.1,
                child: Container(color: AppColors.borderColor(context)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bone(context, width: 60, height: 10),
                  const SizedBox(height: 6),
                  _bone(context, width: double.infinity, height: 12),
                  const SizedBox(height: 4),
                  _bone(context, width: 100, height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bone(BuildContext context, {required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.borderColor(context),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onReset;
  const _EmptyState({required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: 72, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No products found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryColor(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filters.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondaryColor(context),
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: onReset,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(
                    color: Color.fromRGBO(83, 110, 254, 1)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'Reset Filters',
                style: TextStyle(
                  color: Color.fromRGBO(83, 110, 254, 1),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cart bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _CartSheet extends StatelessWidget {
  final MarketplaceController controller;
  const _CartSheet({required this.controller});

  static const _primaryColor = Color.fromRGBO(83, 110, 254, 1);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceColor(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Text('Your Cart',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimaryColor(context),
                        )),
                    const Spacer(),
                    Obx(() => Text(
                      '${controller.cartItemCount} items',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondaryColor(context),
                      ),
                    )),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Obx(() {
                  final entries = controller.cartItems.entries.toList();
                  if (entries.isEmpty) {
                    return Center(
                      child: Text('Your cart is empty',
                          style: TextStyle(color: AppColors.textSecondaryColor(context))),
                    );
                  }
                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final productId = entries[i].key;
                      final qty = entries[i].value;
                      final product = controller.products
                          .firstWhereOrNull((p) => p.id == productId);
                      if (product == null) return const SizedBox.shrink();

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            product.primaryImage,
                            width: 52, height: 52, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 52, height: 52,
                              color: AppColors.cardColor(context),
                              child: const Icon(Icons.image, size: 24),
                            ),
                          ),
                        ),
                        title: Text(product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimaryColor(context),
                            )),
                        subtitle: Text(product.priceFormatted,
                            style: const TextStyle(
                              color: _primaryColor,
                              fontWeight: FontWeight.w700,
                            )),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _cartQtyBtn(Icons.remove, () =>
                                controller.updateCartQuantity(productId, qty - 1)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text('$qty',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: _primaryColor,
                                  )),
                            ),
                            _cartQtyBtn(Icons.add, () =>
                                controller.updateCartQuantity(productId, qty + 1)),
                          ],
                        ),
                      );
                    },
                  );
                }),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Obx(() => Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimaryColor(context),
                              )),
                          Text(
                            '${controller.cartTotal.toStringAsFixed(0)} MAD',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _primaryColor,
                            ),
                          ),
                        ],
                      )),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                _primaryColor,
                                Color.fromRGBO(123, 144, 250, 1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              Get.snackbar(
                                'Coming Soon',
                                'Checkout will be available in the next update.',
                                snackPosition: SnackPosition.BOTTOM,
                                backgroundColor: _primaryColor,
                                colorText: Colors.white,
                                margin: const EdgeInsets.all(16),
                                borderRadius: 12,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('Proceed to Checkout',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                )),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _cartQtyBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: _primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14, color: _primaryColor),
      ),
    );
  }
}
