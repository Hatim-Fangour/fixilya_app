import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fixilya_app/features/marketplace/data/models/product_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// MarketplaceController
/// Manages product loading, filtering, sorting, search, and cart state
/// for the multi-provider marketplace feature.
class MarketplaceController extends GetxController {
  // ─── Services ────────────────────────────────────────────────────────────
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── State: data ─────────────────────────────────────────────────────────
  final products         = <ProductModel>[].obs;   // all products (raw from Firestore or mock)
  final displayedProducts = <ProductModel>[].obs;  // post-filter result shown in grid
  final isLoading        = false.obs;
  final errorMessage     = ''.obs;

  // ─── State: filters ───────────────────────────────────────────────────────
  final selectedCategory = ProductCategory.all.obs;
  final searchQuery      = ''.obs;
  final sortBy           = SortOption.popular.obs;
  final priceRange       = const RangeValues(0, 5000).obs;
  final maxPrice         = 5000.0.obs; // Updated dynamically from loaded data

  // ─── State: cart ─────────────────────────────────────────────────────────
  final cartItems = <String, int>{}.obs; // productId → quantity

  // ─── Computed helpers ─────────────────────────────────────────────────────
  int get cartItemCount =>
      cartItems.values.fold(0, (sum, qty) => sum + qty);

  double get cartTotal {
    double total = 0;
    for (final entry in cartItems.entries) {
      final product = products.firstWhereOrNull((p) => p.id == entry.key);
      if (product != null) total += product.price * entry.value;
    }
    return total;
  }

  // ─── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    loadProducts();
    // Re-apply filters reactively whenever any filter observable changes
    ever(selectedCategory, (_) => applyFilters());
    ever(searchQuery,      (_) => applyFilters());
    ever(sortBy,           (_) => applyFilters());
    ever(priceRange,       (_) => applyFilters());
  }

  // ─── Load products ────────────────────────────────────────────────────────
  Future<void> loadProducts() async {
    isLoading.value  = true;
    errorMessage.value = '';

    try {
      final snapshot = await _firestore
          .collection('products')
          .orderBy('createdAt', descending: true)
          .get();

      if (snapshot.docs.isNotEmpty) {
        products.value = snapshot.docs
            .map((doc) => ProductModel.fromFirestore(doc))
            .toList();
        if (kDebugMode) {
          debugPrint('MarketplaceController: loaded ${products.length} products from Firestore');
        }
      } else {
        // Firestore collection empty → seed with mock data so the UI is
        // populated immediately during development / demo.
        products.value = _mockProducts();
        if (kDebugMode) {
          debugPrint('MarketplaceController: Firestore empty, using ${products.length} mock products');
        }
      }

      // Derive realistic max price from the loaded data set
      if (products.isNotEmpty) {
        final highestPrice = products.map((p) => p.price).reduce((a, b) => a > b ? a : b);
        maxPrice.value = (highestPrice * 1.2).ceilToDouble(); // 20% headroom
        priceRange.value = RangeValues(0, maxPrice.value);
      }

      applyFilters();
    } catch (e) {
      if (kDebugMode) debugPrint('MarketplaceController: loadProducts error: $e');
      // Graceful degradation: show mock data even when Firestore fails
      products.value = _mockProducts();
      applyFilters();
      errorMessage.value = 'Could not connect to server. Showing sample products.';
    } finally {
      isLoading.value = false;
    }
  }

  // ─── Filter + sort pipeline ───────────────────────────────────────────────
  void applyFilters() {
    var result = products.toList();

    // 1. Category filter
    if (selectedCategory.value != ProductCategory.all) {
      result = result
          .where((p) => p.category == selectedCategory.value)
          .toList();
    }

    // 2. Search query (name, tags, provider name)
    final query = searchQuery.value.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((p) {
        return p.name.toLowerCase().contains(query) ||
            p.description.toLowerCase().contains(query) ||
            p.tags.any((t) => t.toLowerCase().contains(query)) ||
            p.provider.name.toLowerCase().contains(query);
      }).toList();
    }

    // 3. Price range
    result = result
        .where((p) => p.price >= priceRange.value.start && p.price <= priceRange.value.end)
        .toList();

    // 4. Sort
    switch (sortBy.value) {
      case SortOption.popular:
        result.sort((a, b) => b.reviewCount.compareTo(a.reviewCount));
        break;
      case SortOption.priceAsc:
        result.sort((a, b) => a.price.compareTo(b.price));
        break;
      case SortOption.priceDesc:
        result.sort((a, b) => b.price.compareTo(a.price));
        break;
      case SortOption.newest:
        result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortOption.rating:
        result.sort((a, b) => b.rating.compareTo(a.rating));
        break;
    }

    displayedProducts.value = result;
  }

  // ─── Filter setters (called from UI) ─────────────────────────────────────
  void setCategory(ProductCategory category) =>
      selectedCategory.value = category;

  void setSearch(String query) => searchQuery.value = query;

  void setSort(SortOption option) => sortBy.value = option;

  void setPriceRange(RangeValues range) => priceRange.value = range;

  void resetFilters() {
    selectedCategory.value = ProductCategory.all;
    searchQuery.value      = '';
    sortBy.value           = SortOption.popular;
    priceRange.value       = RangeValues(0, maxPrice.value);
  }

  // ─── Cart operations ──────────────────────────────────────────────────────
  void addToCart(ProductModel product, {int quantity = 1}) {
    if (!product.inStock) {
      Get.snackbar(
        'Out of Stock',
        '${product.name} is currently unavailable.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    final current = cartItems[product.id] ?? 0;
    cartItems[product.id] = current + quantity;

    Get.snackbar(
      'Added to Cart',
      '${product.name} added successfully.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color.fromRGBO(83, 110, 254, 1),
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 2),
      icon: const Icon(Icons.shopping_cart, color: Colors.white, size: 18),
    );
  }

  void removeFromCart(String productId) {
    cartItems.remove(productId);
  }

  void updateCartQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      cartItems.remove(productId);
    } else {
      cartItems[productId] = quantity;
    }
  }

  int cartQuantityFor(String productId) => cartItems[productId] ?? 0;

  // ─── Mock seed data ───────────────────────────────────────────────────────
  List<ProductModel> _mockProducts() {
    final now = DateTime.now();

    ProductProvider provider(String id, String name, {String? city}) =>
        ProductProvider(id: id, name: name, rating: 4.2, totalSales: 120, city: city);

    return [
      // Materials
      ProductModel(
        id: 'mock_1',
        name: 'Portland Cement 50kg',
        description: 'High-strength Portland cement bag. Ideal for foundations, slabs, and general construction.',
        price: 95,
        category: ProductCategory.materials,
        provider: provider('p1', 'Atlas Matériaux', city: 'Casablanca'),
        images: ['https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=400'],
        rating: 4.3,
        reviewCount: 89,
        inStock: true,
        stockCount: 200,
        tags: ['cement', 'construction', 'foundation'],
        featured: true,
        createdAt: now.subtract(const Duration(days: 30)),
      ),
      ProductModel(
        id: 'mock_2',
        name: 'Red Brick (Pack of 50)',
        description: 'Standard fired clay bricks. Excellent thermal insulation and durability.',
        price: 180,
        originalPrice: 220,
        category: ProductCategory.materials,
        provider: provider('p1', 'Atlas Matériaux', city: 'Casablanca'),
        images: ['https://images.unsplash.com/photo-1504307651254-35680f356dfd?w=400'],
        rating: 4.5,
        reviewCount: 134,
        inStock: true,
        stockCount: 50,
        tags: ['brick', 'masonry', 'wall'],
        createdAt: now.subtract(const Duration(days: 25)),
      ),
      ProductModel(
        id: 'mock_3',
        name: 'Steel Rebar Ø10mm — 6m',
        description: 'High-tensile steel reinforcing bar for concrete structures. Ribbed surface for superior bond.',
        price: 75,
        category: ProductCategory.materials,
        provider: provider('p2', 'SteelPro Maroc', city: 'Mohammedia'),
        images: ['https://images.unsplash.com/photo-1581094794329-c8112a89af12?w=400'],
        rating: 4.1,
        reviewCount: 67,
        inStock: true,
        stockCount: 500,
        tags: ['steel', 'rebar', 'concrete', 'reinforcement'],
        createdAt: now.subtract(const Duration(days: 20)),
      ),

      // Tools
      ProductModel(
        id: 'mock_4',
        name: 'Professional Cordless Drill',
        description: '18V lithium cordless drill with 2 batteries, charger, and 25-piece bit set. Variable speed trigger, forward/reverse switch, and built-in LED work light. Torque: 65Nm. Ideal for wood, metal, and masonry. Ergonomic grip reduces fatigue on long jobs.',
        price: 850,
        originalPrice: 1100,
        category: ProductCategory.tools,
        provider: provider('p3', 'ToolMaster', city: 'Rabat'),
        images: [
          'https://images.unsplash.com/photo-1572981779307-38b8cabb2407?w=600',
          'https://images.unsplash.com/photo-1504148455328-c376907d081c?w=600',
          'https://images.unsplash.com/photo-1581091226825-a6a2a5aee158?w=600',
        ],
        rating: 4.7,
        reviewCount: 212,
        inStock: true,
        stockCount: 15,
        tags: ['drill', 'cordless', 'power tool', '18V'],
        featured: true,
        createdAt: now.subtract(const Duration(days: 15)),
        // Body color variants: classic yellow/black and stealth grey
        colors: ['#F4A900', '#2C2C2C'],
      ),
      ProductModel(
        id: 'mock_5',
        name: 'Angle Grinder 125mm',
        description: 'Heavy duty 850W angle grinder with safety guard and 5 cutting discs included.',
        price: 420,
        category: ProductCategory.tools,
        provider: provider('p3', 'ToolMaster', city: 'Rabat'),
        images: ['https://images.unsplash.com/photo-1504148455328-c376907d081c?w=400'],
        rating: 4.4,
        reviewCount: 88,
        inStock: true,
        stockCount: 20,
        tags: ['grinder', 'power tool', 'cutting'],
        createdAt: now.subtract(const Duration(days: 10)),
      ),
      ProductModel(
        id: 'mock_6',
        name: 'Spirit Level 120cm',
        description: 'Precision aluminum spirit level with 3 vials. Anti-shock protection.',
        price: 135,
        category: ProductCategory.tools,
        provider: provider('p4', 'Brico Express', city: 'Marrakech'),
        images: ['https://images.unsplash.com/photo-1609205830565-fa9b0f3c7b7d?w=400'],
        rating: 4.2,
        reviewCount: 45,
        inStock: true,
        stockCount: 30,
        tags: ['level', 'measurement', 'carpentry'],
        createdAt: now.subtract(const Duration(days: 8)),
      ),

      // Pharmacy / Health
      ProductModel(
        id: 'mock_7',
        name: 'First Aid Kit — Professional 100pcs',
        description: 'Comprehensive first aid kit for construction sites. Bandages, antiseptic, gloves, and more.',
        price: 290,
        originalPrice: 350,
        category: ProductCategory.pharmacy,
        provider: provider('p5', 'MediSupply', city: 'Casablanca'),
        images: ['https://images.unsplash.com/photo-1603398938378-e54eab446dde?w=400'],
        rating: 4.8,
        reviewCount: 156,
        inStock: true,
        stockCount: 40,
        tags: ['first aid', 'safety', 'health', 'emergency'],
        featured: true,
        createdAt: now.subtract(const Duration(days: 5)),
      ),
      ProductModel(
        id: 'mock_8',
        name: 'Safety Gloves — Latex (Box of 100)',
        description: 'Disposable powder-free latex gloves. EN 455 certified for single use in medical and industrial settings. Textured fingertips for better grip. Available in four sizes — order the right fit for your team.',
        price: 85,
        category: ProductCategory.pharmacy,
        provider: provider('p5', 'MediSupply', city: 'Casablanca'),
        images: [
          'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=600',
          'https://images.unsplash.com/photo-1603398938378-e54eab446dde?w=600',
        ],
        rating: 4.0,
        reviewCount: 72,
        inStock: true,
        stockCount: 100,
        tags: ['gloves', 'protection', 'latex'],
        createdAt: now.subtract(const Duration(days: 3)),
        sizes: ['S', 'M', 'L', 'XL'],
      ),

      // Electrical
      ProductModel(
        id: 'mock_9',
        name: 'LED Downlight 9W (Pack of 10)',
        description: 'Recessed LED downlights, warm white 3000K, 220V, 90mm cutout. Energy class A+.',
        price: 320,
        originalPrice: 400,
        category: ProductCategory.electrical,
        provider: provider('p6', 'ElectroPro', city: 'Agadir'),
        images: ['https://images.unsplash.com/photo-1565814329452-e1efa11c5b89?w=400'],
        rating: 4.5,
        reviewCount: 98,
        inStock: true,
        stockCount: 60,
        tags: ['LED', 'lighting', 'downlight', 'energy saving'],
        featured: true,
        createdAt: now.subtract(const Duration(days: 12)),
      ),
      ProductModel(
        id: 'mock_10',
        name: 'Cable NYY 2.5mm² — 100m Reel',
        description: 'PVC-insulated power cable for fixed indoor and outdoor installations. 750V rated.',
        price: 580,
        category: ProductCategory.electrical,
        provider: provider('p6', 'ElectroPro', city: 'Agadir'),
        images: ['https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=400'],
        rating: 4.3,
        reviewCount: 54,
        inStock: false,
        stockCount: 0,
        tags: ['cable', 'wiring', 'electrical'],
        createdAt: now.subtract(const Duration(days: 18)),
      ),

      // Plumbing
      ProductModel(
        id: 'mock_11',
        name: 'Thermostatic Shower Mixer',
        description: 'Precision thermostatic mixer with anti-scald protection — maintains your chosen temperature regardless of pressure fluctuations. Includes overhead rain shower head (200mm) and hand shower with 150cm hose. Ceramic cartridge rated for 500,000 cycles.',
        price: 1200,
        originalPrice: 1500,
        category: ProductCategory.plumbing,
        provider: provider('p7', 'AquaFix', city: 'Fès'),
        images: [
          'https://images.unsplash.com/photo-1552321554-5fefe8c9ef14?w=600',
          'https://images.unsplash.com/photo-1604709177225-055f99402ea3?w=600',
          'https://images.unsplash.com/photo-1586105449897-20b5efeb3233?w=600',
        ],
        rating: 4.6,
        reviewCount: 77,
        inStock: true,
        stockCount: 8,
        tags: ['shower', 'mixer', 'thermostatic', 'bathroom'],
        featured: true,
        createdAt: now.subtract(const Duration(days: 22)),
        // Finish variants: polished chrome, brushed gold, matte black
        colors: ['#C0C0C0', '#CFB53B', '#1C1C1E'],
      ),
      ProductModel(
        id: 'mock_12',
        name: 'PVC Pipe — 3m',
        description: 'Grey PVC drainage pipe, pressure rating PN10. UV-stabilised for outdoor use. Easy push-fit assembly with solvent cement or rubber seal. Suitable for wastewater and rainwater drainage systems.',
        price: 45,
        category: ProductCategory.plumbing,
        provider: provider('p7', 'AquaFix', city: 'Fès'),
        images: [
          'https://images.unsplash.com/photo-1504328345606-18bbc8c9d7d1?w=600',
        ],
        rating: 3.9,
        reviewCount: 33,
        inStock: true,
        stockCount: 120,
        tags: ['PVC', 'pipe', 'drainage', 'plumbing'],
        createdAt: now.subtract(const Duration(days: 14)),
        sizes: ['32mm', '40mm', '50mm', '75mm', '110mm'],
      ),

      // Paint
      ProductModel(
        id: 'mock_13',
        name: 'Interior Latex Paint',
        description: 'Premium washable emulsion paint for interior walls and ceilings. Coverage ~12m²/L per coat. Low VOC formulation is safe for indoor use. Quick drying (touch-dry in 1 hour, recoatable in 4 hours). Excellent opacity — full coverage in 2 coats. Scrub-resistant once cured.',
        price: 480,
        originalPrice: 560,
        category: ProductCategory.paint,
        provider: provider('p8', 'ColorVille', city: 'Casablanca'),
        images: [
          'https://images.unsplash.com/photo-1562259929-b4e1fd3aef09?w=600',
          'https://images.unsplash.com/photo-1589939705384-5185137a7f0f?w=600',
          'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=600',
        ],
        rating: 4.4,
        reviewCount: 119,
        inStock: true,
        stockCount: 25,
        tags: ['paint', 'interior', 'emulsion', 'washable'],
        featured: true,
        createdAt: now.subtract(const Duration(days: 7)),
        // Popular wall colours — select your shade
        colors: ['#FFFFFF', '#F5F0E0', '#A8D5E2', '#F7C5BE', '#B5EAD7', '#C9B1FF'],
        sizes: ['5L', '10L', '20L'],
      ),

      // Cleaning
      ProductModel(
        id: 'mock_14',
        name: 'Industrial Pressure Washer 2500W',
        description: '165 bar electric pressure washer with 10m hose, 5 nozzles, and detergent tank.',
        price: 1850,
        originalPrice: 2200,
        category: ProductCategory.cleaning,
        provider: provider('p9', 'CleanForce', city: 'Casablanca'),
        images: ['https://images.unsplash.com/photo-1585771724684-38269d6639fd?w=400'],
        rating: 4.7,
        reviewCount: 203,
        inStock: true,
        stockCount: 5,
        tags: ['pressure washer', 'cleaning', 'power washer'],
        featured: true,
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      ProductModel(
        id: 'mock_15',
        name: 'Multi-Surface Cleaner 5L',
        description: 'Industrial-strength multi-surface cleaner. Safe on tiles, concrete, and metal.',
        price: 75,
        category: ProductCategory.cleaning,
        provider: provider('p9', 'CleanForce', city: 'Casablanca'),
        images: ['https://images.unsplash.com/photo-1563453392212-326f5e854473?w=400'],
        rating: 4.1,
        reviewCount: 61,
        inStock: true,
        stockCount: 80,
        tags: ['cleaner', 'detergent', 'multi-surface'],
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ];
  }
}
