import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/features/marketplace/data/models/product_model.dart';
import 'package:fixilya_app/features/marketplace/presentation/controllers/marketplace_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Full-screen product detail page.
///
/// Receives a [ProductModel] directly (no route arguments needed — the card
/// already has the full object). Opened via [Get.to] with a Hero transition
/// from the card image.
class ProductDetailPage extends StatefulWidget {
  final ProductModel product;
  const ProductDetailPage({super.key, required this.product});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  static const _primary = Color.fromRGBO(83, 110, 254, 1);
  static const _secondary = Color.fromRGBO(123, 144, 250, 1);

  // ── Cached controller ──────────────────────────────────────────────────────
  // Retrieved once in initState — NOT in build(). Calling Get.find inside
  // build() races against GetX's SmartManagement which may dispose the
  // controller when a new route is pushed (permanent: false). Caching here
  // guarantees we hold a live reference for the entire page lifetime.
  late final MarketplaceController _controller;

  late final PageController _imageCtrl;
  int _currentImage = 0;
  String? _selectedColor;
  String? _selectedSize;
  int _quantity = 1;
  bool _descExpanded = false;

  @override
  void initState() {
    super.initState();

    // Grab the controller before any route transition can trigger disposal
    _controller = Get.find<MarketplaceController>();

    _imageCtrl = PageController();

    // Pre-select the first variant so the picker always shows a selection
    if (widget.product.colors.isNotEmpty) {
      _selectedColor = widget.product.colors.first;
    }
    if (widget.product.sizes.isNotEmpty) {
      _selectedSize = widget.product.sizes.first;
    }

    // Sync local quantity with current cart state.
    // If the user already added 2 of this product via the grid card,
    // the detail page should open showing 2, not 1.
    final cartQty = _controller.cartQuantityFor(widget.product.id);
    if (cartQty > 0) _quantity = cartQty;
  }

  @override
  void dispose() {
    _imageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final images =
        product.images.isNotEmpty ? product.images : [product.primaryImage];

    return Scaffold(
      backgroundColor: AppColors.backgroundColor(context),
      body: Stack(
        children: [
          // ── Scrollable content ────────────────────────────────────────
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Image gallery header
              SliverAppBar(
                expandedHeight: 350,
                pinned: true,
                stretch: true,
                backgroundColor: Colors.black87,
                // Custom back button with glass effect
                leading: _GlassButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Get.back(),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [StretchMode.zoomBackground],
                  background: _ImageGallery(
                    images: images,
                    productId: product.id,
                    pageController: _imageCtrl,
                    currentIndex: _currentImage,
                    onPageChanged: (i) =>
                        setState(() => _currentImage = i),
                  ),
                ),
              ),

              // ── Content card (rounded top overlaps image bottom)
              SliverToBoxAdapter(
                child: Container(
                  // Rounded top corners give the "card rising over the image" look
                  decoration: BoxDecoration(
                    color: AppColors.backgroundColor(context),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  // Translate upward to create the overlap with the gallery
                  transform: Matrix4.translationValues(0, -24, 0),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 160),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Category chip + provider
                        _ProviderAndCategoryRow(product: product),
                        const SizedBox(height: 8),

                        // ── Product name
                        Text(
                          product.name,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimaryColor(context),
                            height: 1.2,
                          ),
                        ),

                        // ── Star rating
                        if (product.reviewCount > 0) ...[
                          const SizedBox(height: 6),
                          _RatingRow(product: product),
                        ],

                        // ── Price
                        const SizedBox(height: 12),
                        _PriceRow(product: product),

                        // ── Stock indicator
                        const SizedBox(height: 8),
                        _StockBadge(product: product),

                        // ── Divider
                        const SizedBox(height: 20),
                        Divider(height: 1, color: AppColors.dividerColor(context)),
                        const SizedBox(height: 20),

                        // ── Color picker (only when product has color variants)
                        if (product.colors.isNotEmpty) ...[
                          _ColorPicker(
                            colors: product.colors,
                            selected: _selectedColor,
                            onSelect: (c) =>
                                setState(() => _selectedColor = c),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // ── Size picker (only when product has size variants)
                        if (product.sizes.isNotEmpty) ...[
                          _SizePicker(
                            sizes: product.sizes,
                            selected: _selectedSize,
                            onSelect: (s) =>
                                setState(() => _selectedSize = s),
                          ),
                          const SizedBox(height: 20),
                        ],

                        if (product.colors.isNotEmpty ||
                            product.sizes.isNotEmpty) ...[
                          Divider(height: 1, color: AppColors.dividerColor(context)),
                          const SizedBox(height: 20),
                        ],

                        // ── Description
                        _DescriptionSection(
                          description: product.description,
                          isExpanded: _descExpanded,
                          onToggle: () => setState(
                              () => _descExpanded = !_descExpanded),
                        ),

                        // ── Tags
                        if (product.tags.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Divider(height: 1, color: AppColors.dividerColor(context)),
                          const SizedBox(height: 20),
                          _TagsSection(tags: product.tags),
                        ],

                        // ── Provider info card
                        const SizedBox(height: 20),
                        Divider(height: 1, color: AppColors.dividerColor(context)),
                        const SizedBox(height: 20),
                        _ProviderCard(provider: product.provider),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Sticky bottom bar wrapped in Obx so cart state drives the UI
          // reactively — badge count, button label, and in-cart indicator all
          // update instantly when cartItems changes.
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Obx(() {
              // Reading cartItems inside Obx registers this widget as a
              // reactive listener — any addToCart / updateCartQuantity call
              // automatically rebuilds this bar with the latest cart state.
              final cartQty = _controller.cartQuantityFor(product.id);
              return _StickyAddToCart(
                product: product,
                quantity: _quantity,
                cartQty: cartQty,
                onDecrement: () {
                  if (_quantity > 1) setState(() => _quantity--);
                },
                onIncrement: () {
                  final max =
                      product.stockCount > 0 ? product.stockCount : 99;
                  if (_quantity < max) setState(() => _quantity++);
                },
                onAddToCart: () {
                  _controller.addToCart(product, quantity: _quantity);
                  // Reset local picker back to 1 after a successful add
                  setState(() => _quantity = 1);
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glass back / action button (used in the SliverAppBar leading)
// ─────────────────────────────────────────────────────────────────────────────

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Image gallery: PageView + Hero on index-0 + dot indicator + counter
// ─────────────────────────────────────────────────────────────────────────────

class _ImageGallery extends StatelessWidget {
  final List<String> images;
  final String productId;
  final PageController pageController;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;

  const _ImageGallery({
    required this.images,
    required this.productId,
    required this.pageController,
    required this.currentIndex,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Swipeable image pages
        PageView.builder(
          controller: pageController,
          onPageChanged: onPageChanged,
          itemCount: images.length,
          itemBuilder: (_, index) {
            final img = Image.network(
              images[index],
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey.shade300,
                child: const Icon(
                  Icons.image_not_supported_outlined,
                  size: 48,
                  color: Colors.grey,
                ),
              ),
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
            );

            // Only the FIRST image gets the Hero tag — it matches the tag used in
            // ProductCard so Flutter can animate the morph between card and detail.
            if (index == 0) {
              return Hero(
                tag: 'product_image_$productId',
                child: img,
              );
            }
            return img;
          },
        ),

        // ── Bottom gradient for legibility of dots / counter
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // ── Dot indicator (only shown when more than one image)
        if (images.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: _DotIndicator(
              count: images.length,
              current: currentIndex,
            ),
          ),

        // ── "1 / 3" counter pill (top-right below the status bar)
        if (images.length > 1)
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            right: 16,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${currentIndex + 1} / ${images.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DotIndicator extends StatelessWidget {
  final int count;
  final int current;
  const _DotIndicator({required this.count, required this.current});

  static const _primary = Color.fromRGBO(83, 110, 254, 1);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 22 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active
                ? _primary
                : Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider + category chip row
// ─────────────────────────────────────────────────────────────────────────────

class _ProviderAndCategoryRow extends StatelessWidget {
  final ProductModel product;
  const _ProviderAndCategoryRow({required this.product});

  static const _primary = Color.fromRGBO(83, 110, 254, 1);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            product.category.label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _primary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'by ${product.provider.name}',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondaryColor(context),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Star rating row
// ─────────────────────────────────────────────────────────────────────────────

class _RatingRow extends StatelessWidget {
  final ProductModel product;
  const _RatingRow({required this.product});

  @override
  Widget build(BuildContext context) {
    final full = product.rating.floor();
    final half = product.rating - full >= 0.5;

    return Row(
      children: [
        ...List.generate(5, (i) {
          IconData icon;
          if (i < full) {
            icon = Icons.star_rounded;
          } else if (i == full && half) {
            icon = Icons.star_half_rounded;
          } else {
            icon = Icons.star_outline_rounded;
          }
          return Icon(icon, size: 17, color: Colors.amber);
        }),
        const SizedBox(width: 6),
        Text(
          product.rating.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimaryColor(context),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '(${product.reviewCount} reviews)',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondaryColor(context),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Price row: current price + struck-through original + discount badge
// ─────────────────────────────────────────────────────────────────────────────

class _PriceRow extends StatelessWidget {
  final ProductModel product;
  const _PriceRow({required this.product});

  static const _primary = Color.fromRGBO(83, 110, 254, 1);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 10,
      children: [
        Text(
          product.priceFormatted,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: _primary,
          ),
        ),
        if (product.hasDiscount) ...[
          Text(
            product.originalPriceFormatted,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondaryColor(context),
              decoration: TextDecoration.lineThrough,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '-${product.discountPercent}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stock status badge
// ─────────────────────────────────────────────────────────────────────────────

class _StockBadge extends StatelessWidget {
  final ProductModel product;
  const _StockBadge({required this.product});

  @override
  Widget build(BuildContext context) {
    if (!product.inStock) {
      return _badge(Icons.cancel_outlined, 'Out of Stock', Colors.red);
    }
    final lowStock = product.stockCount > 0 && product.stockCount <= 5;
    if (lowStock) {
      return _badge(
        Icons.warning_amber_rounded,
        'Only ${product.stockCount} left — order soon!',
        Colors.orange,
      );
    }
    final countLabel = product.stockCount > 0
        ? 'In Stock  ·  ${product.stockCount} available'
        : 'In Stock';
    return _badge(Icons.check_circle_outline_rounded, countLabel, Colors.green);
  }

  Widget _badge(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Color picker — circular swatches with check-mark on selection
// ─────────────────────────────────────────────────────────────────────────────

class _ColorPicker extends StatelessWidget {
  final List<String> colors;
  final String? selected;
  final ValueChanged<String> onSelect;

  const _ColorPicker({
    required this.colors,
    required this.selected,
    required this.onSelect,
  });

  static const _primary = Color.fromRGBO(83, 110, 254, 1);

  /// Convert a '#RRGGBB' hex string to a Flutter Color (always fully opaque).
  Color _fromHex(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
  }

  /// W3C luminance formula — determines whether white or black looks better
  /// as the check icon on top of [c].
  bool _isLight(Color c) =>
      (c.red * 299 + c.green * 587 + c.blue * 114) / 1000 > 180;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Color',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryColor(context),
              ),
            ),
            if (selected != null) ...[
              const SizedBox(width: 8),
              // Show the hex value of the selected color as a subtle label
              Text(
                selected!.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondaryColor(context),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: colors.map((hex) {
            final color = _fromHex(hex);
            final isSelected = selected == hex;
            return GestureDetector(
              onTap: () => onSelect(hex),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    // Light-coloured swatches get a grey border so they're
                    // visible against a white background.
                    color: isSelected
                        ? _primary
                        : (_isLight(color)
                            ? Colors.grey.shade300
                            : Colors.transparent),
                    width: isSelected ? 3 : 1.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: _primary.withValues(alpha: 0.4),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: isSelected
                    ? Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: _isLight(color) ? Colors.black87 : Colors.white,
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Size picker — pill-shaped chips
// ─────────────────────────────────────────────────────────────────────────────

class _SizePicker extends StatelessWidget {
  final List<String> sizes;
  final String? selected;
  final ValueChanged<String> onSelect;

  const _SizePicker({
    required this.sizes,
    required this.selected,
    required this.onSelect,
  });

  static const _primary = Color.fromRGBO(83, 110, 254, 1);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Size',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryColor(context),
              ),
            ),
            if (selected != null) ...[
              const SizedBox(width: 8),
              Text(
                selected!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _primary,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: sizes.map((size) {
            final isSelected = selected == size;
            return GestureDetector(
              onTap: () => onSelect(size),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? _primary : AppColors.cardColor(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? _primary
                        : AppColors.borderColor(context),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: _primary.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  size,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : AppColors.textPrimaryColor(context),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Description with Read more / Read less toggle
// ─────────────────────────────────────────────────────────────────────────────

class _DescriptionSection extends StatelessWidget {
  final String description;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _DescriptionSection({
    required this.description,
    required this.isExpanded,
    required this.onToggle,
  });

  // Descriptions shorter than this threshold are shown in full with no toggle.
  static const _truncateAt = 140;

  @override
  Widget build(BuildContext context) {
    final needsTruncation = description.length > _truncateAt;
    final displayText =
        needsTruncation && !isExpanded
            ? '${description.substring(0, _truncateAt)}…'
            : description;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimaryColor(context),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 250),
          crossFadeState: isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: Text(
            displayText,
            style: TextStyle(
              fontSize: 14,
              height: 1.65,
              color: AppColors.textSecondaryColor(context),
            ),
          ),
          secondChild: Text(
            description,
            style: TextStyle(
              fontSize: 14,
              height: 1.65,
              color: AppColors.textSecondaryColor(context),
            ),
          ),
        ),
        if (needsTruncation) ...[
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onToggle,
            child: Text(
              isExpanded ? 'Read less' : 'Read more',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color.fromRGBO(83, 110, 254, 1),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tags
// ─────────────────────────────────────────────────────────────────────────────

class _TagsSection extends StatelessWidget {
  final List<String> tags;
  const _TagsSection({required this.tags});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tags',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimaryColor(context),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: tags
              .map(
                (tag) => Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.cardColor(context),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: AppColors.borderColor(context)),
                  ),
                  child: Text(
                    '#$tag',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryColor(context),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider info card
// ─────────────────────────────────────────────────────────────────────────────

class _ProviderCard extends StatelessWidget {
  final ProductProvider provider;
  const _ProviderCard({required this.provider});

  static const _primary = Color.fromRGBO(83, 110, 254, 1);
  static const _secondary = Color.fromRGBO(123, 144, 250, 1);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor(context)),
      ),
      child: Row(
        children: [
          // Avatar with gradient + first letter
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [_primary, _secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                provider.name.isNotEmpty
                    ? provider.name[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Provider name + stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 10,
                  children: [
                    _statChip(Icons.star_rounded, Colors.amber,
                        provider.rating.toStringAsFixed(1)),
                    if (provider.totalSales > 0)
                      _statChip(Icons.shopping_bag_outlined,
                          AppColors.textSecondaryColor(context),
                          '${provider.totalSales} sales'),
                    if (provider.city != null)
                      _statChip(Icons.location_on_outlined,
                          AppColors.textSecondaryColor(context),
                          provider.city!),
                  ],
                ),
              ],
            ),
          ),

          // View store CTA
          TextButton(
            onPressed: () {
              // TODO: Navigate to provider storefront page
            },
            style: TextButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: _primary,
            ),
            child: const Text(
              'Store',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sticky bottom bar — quantity stepper + Add to Cart with live total
//
// [cartQty] = how many of this product are already in the cart (from Obx).
// When cartQty > 0 we show a subtle "in cart" pill above the bar so the user
// always knows their running cart state for this product.
// ─────────────────────────────────────────────────────────────────────────────

class _StickyAddToCart extends StatelessWidget {
  final ProductModel product;
  final int quantity;  // local picker quantity (how many to add this tap)
  final int cartQty;   // current quantity already in cart (reactive via Obx)
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback onAddToCart;

  const _StickyAddToCart({
    required this.product,
    required this.quantity,
    required this.cartQty,
    required this.onDecrement,
    required this.onIncrement,
    required this.onAddToCart,
  });

  static const _primary = Color.fromRGBO(83, 110, 254, 1);
  static const _secondary = Color.fromRGBO(123, 144, 250, 1);

  @override
  Widget build(BuildContext context) {
    final oos = !product.inStock;
    // Live total = price × picker quantity (updates as user taps +/−)
    final total = (product.price * quantity).toStringAsFixed(0);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor(context),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── "Already in cart" pill — only visible when cartQty > 0
          if (cartQty > 0) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: _primary.withValues(alpha: 0.25), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shopping_cart_rounded,
                      size: 13, color: _primary),
                  const SizedBox(width: 5),
                  Text(
                    '$cartQty already in your cart',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _primary,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Stepper + button row
          Row(
            children: [
              // ── Quantity stepper
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.borderColor(context)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _QtyBtn(
                      icon: Icons.remove_rounded,
                      onTap: onDecrement,
                      enabled: quantity > 1 && !oos,
                    ),
                    SizedBox(
                      width: 38,
                      child: Text(
                        '$quantity',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: oos ? Colors.grey : _primary,
                        ),
                      ),
                    ),
                    _QtyBtn(
                      icon: Icons.add_rounded,
                      onTap: onIncrement,
                      enabled: !oos,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // ── Add to Cart button (fills remaining width, shows live total)
              Expanded(
                child: GestureDetector(
                  onTap: oos ? null : onAddToCart,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: oos
                          ? null
                          : const LinearGradient(
                              colors: [_primary, _secondary],
                            ),
                      color:
                          oos ? Colors.grey.withValues(alpha: 0.25) : null,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: oos
                          ? null
                          : [
                              BoxShadow(
                                color: _primary.withValues(alpha: 0.4),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          oos
                              ? Icons.remove_shopping_cart_outlined
                              : Icons.add_shopping_cart_rounded,
                          color: oos ? Colors.grey : Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          oos
                              ? 'Out of Stock'
                              : cartQty > 0
                                  // Already in cart → show "Add X More"
                                  ? 'Add $quantity More  ·  $total MAD'
                                  // First add
                                  : 'Add to Cart  ·  $total MAD',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: oos ? Colors.grey : Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
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

/// Compact icon button used inside the quantity stepper.
class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  const _QtyBtn({
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  static const _primary = Color.fromRGBO(83, 110, 254, 1);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? _primary : Colors.grey.shade400,
        ),
      ),
    );
  }
}
