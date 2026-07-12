import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/features/marketplace/data/models/product_model.dart';
import 'package:fixilya_app/features/marketplace/presentation/controllers/marketplace_controller.dart';
import 'package:fixilya_app/features/marketplace/presentation/screens/product_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ProductCard extends StatelessWidget {
  final ProductModel product;

  const ProductCard({super.key, required this.product});

  static const _primaryColor = Color.fromRGBO(83, 110, 254, 1);

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MarketplaceController>();

    return GestureDetector(
      // Tap anywhere on the card to open the detail page.
      // The Hero on the image creates a smooth morphing transition.
      onTap: () => Get.to(
        () => ProductDetailPage(product: product),
        transition: Transition.fadeIn,
        duration: const Duration(milliseconds: 300),
      ),
      child: Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor(context),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // Column fills the full grid-cell height (set by mainAxisExtent).
      // Image takes its natural aspect-ratio height; details section gets
      // Expanded so it fills whatever remains — no overflow regardless of
      // how many optional rows (rating, discount price) are rendered.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Product image (Hero-tagged so it morphs into the detail gallery)
          Hero(
            tag: 'product_image_${product.id}',
            child: _ProductImage(product: product),
          ),

          // ── Details (Expanded fills remaining height) ───────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Provider name
                  Text(
                    product.provider.name,
                    style: TextStyle(
                      fontSize: 10,
                      color: _primaryColor.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),

                  // Product name
                  Text(
                    product.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryColor(context),
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Rating (only shown when reviews exist)
                  if (product.reviewCount > 0) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 11, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(
                          product.rating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondaryColor(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '(${product.reviewCount})',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondaryColor(context),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Spacer pushes price + cart to the bottom of the card
                  const Spacer(),

                  // Price row + cart button
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (product.hasDiscount)
                              Text(
                                product.originalPriceFormatted,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondaryColor(context),
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            Text(
                              product.priceFormatted,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: _primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Add-to-cart / quantity stepper
                      Obx(() {
                        final qty = controller.cartQuantityFor(product.id);
                        if (qty > 0) {
                          return _QuantityControl(
                            quantity: qty,
                            onDecrement: () =>
                                controller.updateCartQuantity(product.id, qty - 1),
                            onIncrement: () => controller.addToCart(product),
                          );
                        }
                        return GestureDetector(
                          onTap: () => controller.addToCart(product),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              gradient: product.inStock
                                  ? const LinearGradient(colors: [
                                      Color.fromRGBO(83, 110, 254, 1),
                                      Color.fromRGBO(123, 144, 250, 1),
                                    ])
                                  : null,
                              color: product.inStock
                                  ? null
                                  : Colors.grey.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.add_shopping_cart,
                              size: 15,
                              color: product.inStock ? Colors.white : Colors.grey,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ), // Container
    ); // GestureDetector
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Image section extracted to keep ProductCard.build readable
// ─────────────────────────────────────────────────────────────────────────────

class _ProductImage extends StatelessWidget {
  final ProductModel product;
  const _ProductImage({required this.product});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: AspectRatio(
            aspectRatio: 1.2, // slightly taller ratio = shorter image = more room for details
            child: Image.network(
              product.primaryImage,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.cardColor(context),
                child: const Icon(
                  Icons.image_not_supported_outlined,
                  size: 36,
                  color: Colors.grey,
                ),
              ),
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: AppColors.cardColor(context),
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
            ),
          ),
        ),

        // Discount badge
        if (product.hasDiscount)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '-${product.discountPercent}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

        // Out-of-stock overlay
        if (!product.inStock)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Container(
                color: Colors.black.withValues(alpha: 0.45),
                alignment: Alignment.center,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Out of Stock',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compact quantity stepper shown inside the card once an item is in cart
// ─────────────────────────────────────────────────────────────────────────────

class _QuantityControl extends StatelessWidget {
  final int quantity;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _QuantityControl({
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
  });

  static const _primaryColor = Color.fromRGBO(83, 110, 254, 1);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      decoration: BoxDecoration(
        border: Border.all(color: _primaryColor.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _iconBtn(Icons.remove, onDecrement),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Text(
              '$quantity',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _primaryColor,
              ),
            ),
          ),
          _iconBtn(Icons.add, onIncrement),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Icon(icon, size: 13, color: _primaryColor),
      ),
    );
  }
}
