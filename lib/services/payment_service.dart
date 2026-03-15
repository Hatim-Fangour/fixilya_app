/// Services - Payment Service
/// Complete Payment Processing Service
///
/// Features:
/// - Payment intent creation
/// - Payment processing
/// - Refund handling
/// - Card validation (Luhn algorithm)
/// - Payment method management
/// - Transaction history
/// - Fee calculations
/// - Multi-currency support
library;

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  // Configuration
  String? _publishableKey;
  // NOTE: Secret keys must NEVER be stored on the client. All payment
  // processing that requires a secret key must go through the backend.
  String _defaultCurrency = 'MAD'; // Moroccan Dirham

  // ==================== Initialization ====================

  /// Initialize payment service with the publishable (public) key only.
  /// The secret key is handled exclusively on the server side.
  void initialize({
    required String publishableKey,
    String defaultCurrency = 'MAD',
  }) {
    _publishableKey = publishableKey;
    _defaultCurrency = defaultCurrency;
  }

  // ==================== Payment Intent ====================

  /// Create payment intent.
  /// TODO: Replace this mock with a real call to your backend's payment
  /// endpoint (e.g., POST /api/payments/create-intent). The backend creates
  /// the Stripe PaymentIntent using the secret key and returns the
  /// client_secret to the app. Never generate client secrets on the client.
  Future<PaymentIntent> createPaymentIntent({
    required double amount,
    String? currency,
    String? description,
    String? customerId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // TODO: Call backend API to create a real PaymentIntent.
      // The backend should return the PaymentIntent id and client_secret.
      await Future.delayed(Duration(milliseconds: 500)); // Simulate API call

      return PaymentIntent(
        id: 'pi_mock_${DateTime.now().millisecondsSinceEpoch}',
        amount: amount,
        currency: currency ?? _defaultCurrency,
        status: PaymentStatus.requiresPaymentMethod,
        // Placeholder: in production, this comes from the backend response
        clientSecret: '',
        description: description,
        customerId: customerId,
        metadata: metadata,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      throw PaymentException(
        'Failed to create payment intent: ${e.toString()}',
      );
    }
  }

  /// Confirm payment intent
  Future<PaymentIntent> confirmPaymentIntent({
    required String paymentIntentId,
    required PaymentMethodData paymentMethod,
  }) async {
    try {
      await Future.delayed(Duration(seconds: 2)); // Simulate processing

      return PaymentIntent(
        id: paymentIntentId,
        amount: 0, // Would be fetched from server
        currency: _defaultCurrency,
        status: PaymentStatus.succeeded,
        clientSecret: '',
        createdAt: DateTime.now(),
      );
    } catch (e) {
      throw PaymentException('Payment confirmation failed: ${e.toString()}');
    }
  }

  /// Get payment intent
  Future<PaymentIntent> getPaymentIntent(String paymentIntentId) async {
    try {
      // Fetch from API
      await Future.delayed(Duration(milliseconds: 300));

      return PaymentIntent(
        id: paymentIntentId,
        amount: 0,
        currency: _defaultCurrency,
        status: PaymentStatus.succeeded,
        clientSecret: '',
        createdAt: DateTime.now(),
      );
    } catch (e) {
      throw PaymentException('Failed to get payment intent: ${e.toString()}');
    }
  }

  // ==================== Payment Processing ====================

  /// Process payment
  Future<PaymentResult> processPayment({
    required double amount,
    required PaymentMethodData paymentMethod,
    String? currency,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Validate payment method
      if (paymentMethod.type == PaymentMethodType.card) {
        final isValid = validateCardNumber(paymentMethod.cardNumber!);
        if (!isValid) {
          return PaymentResult(
            success: false,
            error: 'Invalid card number',
            status: PaymentStatus.failed,
            createdAt: DateTime.now(),
          );
        }
      }

      // Create payment intent
      final intent = await createPaymentIntent(
        amount: amount,
        currency: currency,
        description: description,
        metadata: metadata,
      );

      // Confirm payment
      final confirmed = await confirmPaymentIntent(
        paymentIntentId: intent.id,
        paymentMethod: paymentMethod,
      );

      return PaymentResult(
        success: true,
        paymentIntentId: confirmed.id,
        transactionId: 'txn_${DateTime.now().millisecondsSinceEpoch}',
        amount: amount,
        currency: currency ?? _defaultCurrency,
        status: confirmed.status,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      return PaymentResult(
        success: false,
        error: e.toString(),
        status: PaymentStatus.failed,
        createdAt: DateTime.now(),
      );
    }
  }

  /// Process cash payment (for in-person payments)
  Future<PaymentResult> processCashPayment({
    required double amount,
    required String bookingId,
    String? currency,
  }) async {
    return PaymentResult(
      success: true,
      transactionId: 'cash_${DateTime.now().millisecondsSinceEpoch}',
      amount: amount,
      currency: currency ?? _defaultCurrency,
      status: PaymentStatus.succeeded,
      metadata: {'paymentMethod': 'cash', 'bookingId': bookingId},
      createdAt: DateTime.now(),
    );
  }

  // ==================== Refunds ====================

  /// Create refund
  Future<RefundResult> refundPayment({
    required String paymentIntentId,
    required double amount,
    String? reason,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await Future.delayed(Duration(seconds: 1)); // Simulate processing

      return RefundResult(
        success: true,
        refundId: 'ref_${DateTime.now().millisecondsSinceEpoch}',
        paymentIntentId: paymentIntentId,
        amount: amount,
        status: RefundStatus.succeeded,
        reason: reason,
        metadata: metadata,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      return RefundResult(
        success: false,
        error: e.toString(),
        status: RefundStatus.failed,
        createdAt: DateTime.now(),
      );
    }
  }

  /// Get refund status
  Future<RefundResult> getRefundStatus(String refundId) async {
    try {
      await Future.delayed(Duration(milliseconds: 300));

      return RefundResult(
        success: true,
        refundId: refundId,
        amount: 0,
        status: RefundStatus.succeeded,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      throw PaymentException('Failed to get refund status: ${e.toString()}');
    }
  }

  // ==================== Payment Methods ====================

  /// Save payment method
  Future<SavedPaymentMethod> savePaymentMethod({
    required String customerId,
    required PaymentMethodData paymentMethod,
  }) async {
    try {
      await Future.delayed(Duration(milliseconds: 500));

      return SavedPaymentMethod(
        id: 'pm_${DateTime.now().millisecondsSinceEpoch}',
        type: paymentMethod.type,
        cardBrand: paymentMethod.cardBrand,
        last4: paymentMethod.cardNumber?.substring(
          paymentMethod.cardNumber!.length - 4,
        ),
        expiryMonth: paymentMethod.expiryMonth,
        expiryYear: paymentMethod.expiryYear,
        isDefault: false,
      );
    } catch (e) {
      throw PaymentException('Failed to save payment method: ${e.toString()}');
    }
  }

  /// Get saved payment methods
  Future<List<SavedPaymentMethod>> getSavedPaymentMethods(
    String customerId,
  ) async {
    try {
      await Future.delayed(Duration(milliseconds: 300));
      return [];
    } catch (e) {
      throw PaymentException('Failed to get payment methods: ${e.toString()}');
    }
  }

  /// Delete payment method
  Future<void> deletePaymentMethod(String paymentMethodId) async {
    try {
      await Future.delayed(Duration(milliseconds: 300));
    } catch (e) {
      throw PaymentException(
        'Failed to delete payment method: ${e.toString()}',
      );
    }
  }

  /// Set default payment method
  Future<void> setDefaultPaymentMethod({
    required String customerId,
    required String paymentMethodId,
  }) async {
    try {
      await Future.delayed(Duration(milliseconds: 300));
    } catch (e) {
      throw PaymentException(
        'Failed to set default payment method: ${e.toString()}',
      );
    }
  }

  // ==================== Card Validation ====================

  /// Validate card number using Luhn algorithm
  bool validateCardNumber(String cardNumber) {
    final cleaned = cardNumber.replaceAll(RegExp(r'\s+'), '');

    if (cleaned.length < 13 || cleaned.length > 19) {
      return false;
    }

    int sum = 0;
    bool isEven = false;

    for (int i = cleaned.length - 1; i >= 0; i--) {
      int digit = int.tryParse(cleaned[i]) ?? 0;

      if (isEven) {
        digit *= 2;
        if (digit > 9) {
          digit -= 9;
        }
      }

      sum += digit;
      isEven = !isEven;
    }

    return sum % 10 == 0;
  }

  /// Validate expiry date
  bool validateExpiryDate(String month, String year) {
    final now = DateTime.now();
    final expMonth = int.tryParse(month);
    final expYear = int.tryParse(year);

    if (expMonth == null || expYear == null) return false;
    if (expMonth < 1 || expMonth > 12) return false;

    final fullYear = expYear < 100 ? 2000 + expYear : expYear;
    final expiryDate = DateTime(fullYear, expMonth + 1, 0);

    return expiryDate.isAfter(now);
  }

  /// Validate CVV
  bool validateCVV(String cvv, CardBrand? brand) {
    final length = cvv.length;

    if (brand == CardBrand.amex) {
      return length == 4 && int.tryParse(cvv) != null;
    }

    return length == 3 && int.tryParse(cvv) != null;
  }

  /// Get card brand from number
  CardBrand getCardBrand(String cardNumber) {
    final cleaned = cardNumber.replaceAll(RegExp(r'\s+'), '');

    if (cleaned.startsWith(RegExp(r'^4'))) {
      return CardBrand.visa;
    } else if (cleaned.startsWith(RegExp(r'^5[1-5]'))) {
      return CardBrand.mastercard;
    } else if (cleaned.startsWith(RegExp(r'^3[47]'))) {
      return CardBrand.amex;
    } else if (cleaned.startsWith(RegExp(r'^6(?:011|5)'))) {
      return CardBrand.discover;
    } else if (cleaned.startsWith(RegExp(r'^35'))) {
      return CardBrand.jcb;
    } else {
      return CardBrand.unknown;
    }
  }

  // ==================== Fee Calculations ====================

  /// Calculate processing fee
  double calculateProcessingFee(double amount, {double percentage = 2.9}) {
    return (amount * percentage / 100) + 0.30;
  }

  /// Calculate total amount with fee
  double calculateTotalWithFee(double amount) {
    return amount + calculateProcessingFee(amount);
  }

  /// Calculate VAT/Tax
  double calculateTax(double amount, {double taxRate = 20.0}) {
    return amount * taxRate / 100;
  }

  /// Calculate total with tax
  double calculateTotalWithTax(double amount, {double taxRate = 20.0}) {
    return amount + calculateTax(amount, taxRate: taxRate);
  }

  // ==================== Currency ====================

  /// Format amount
  String formatAmount(double amount, {String? currency}) {
    final curr = currency ?? _defaultCurrency;
    return '$amount $curr';
  }

  /// Parse amount
  double parseAmount(String amount) {
    return double.tryParse(amount.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
  }

  // ==================== Helpers ====================

  /// Mask card number
  String maskCardNumber(String cardNumber) {
    if (cardNumber.length < 4) return cardNumber;

    final last4 = cardNumber.substring(cardNumber.length - 4);
    return '**** **** **** $last4';
  }

  /// Format card number
  String formatCardNumber(String cardNumber) {
    final cleaned = cardNumber.replaceAll(RegExp(r'\s+'), '');
    final buffer = StringBuffer();

    for (int i = 0; i < cleaned.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(cleaned[i]);
    }

    return buffer.toString();
  }
}

// ==================== Models ====================

/// Payment Intent
class PaymentIntent {
  final String id;
  final double amount;
  final String currency;
  final PaymentStatus status;
  final String clientSecret;
  final String? description;
  final String? customerId;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  PaymentIntent({
    required this.id,
    required this.amount,
    required this.currency,
    required this.status,
    required this.clientSecret,
    this.description,
    this.customerId,
    this.metadata,
    required this.createdAt,
  });
}

/// Payment Result
class PaymentResult {
  final bool success;
  final String? paymentIntentId;
  final String? transactionId;
  final double? amount;
  final String? currency;
  final PaymentStatus status;
  final String? error;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  PaymentResult({
    required this.success,
    this.paymentIntentId,
    this.transactionId,
    this.amount,
    this.currency,
    required this.status,
    this.error,
    this.metadata,
    required this.createdAt,
  });
}

/// Refund Result
class RefundResult {
  final bool success;
  final String? refundId;
  final String? paymentIntentId;
  final double? amount;
  final RefundStatus status;
  final String? reason;
  final String? error;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  RefundResult({
    required this.success,
    this.refundId,
    this.paymentIntentId,
    this.amount,
    required this.status,
    this.reason,
    this.error,
    this.metadata,
    required this.createdAt,
  });
}

/// Payment Method Data
class PaymentMethodData {
  final PaymentMethodType type;
  final String? cardNumber;
  final String? expiryMonth;
  final String? expiryYear;
  final String? cvv;
  final String? cardholderName;
  final CardBrand? cardBrand;

  PaymentMethodData({
    required this.type,
    this.cardNumber,
    this.expiryMonth,
    this.expiryYear,
    this.cvv,
    this.cardholderName,
    this.cardBrand,
  });
}

/// Saved Payment Method
class SavedPaymentMethod {
  final String id;
  final PaymentMethodType type;
  final CardBrand? cardBrand;
  final String? last4;
  final String? expiryMonth;
  final String? expiryYear;
  final bool isDefault;

  SavedPaymentMethod({
    required this.id,
    required this.type,
    this.cardBrand,
    this.last4,
    this.expiryMonth,
    this.expiryYear,
    this.isDefault = false,
  });
}

/// Payment Status
enum PaymentStatus {
  requiresPaymentMethod,
  requiresConfirmation,
  requiresAction,
  processing,
  succeeded,
  failed,
  cancelled,
}

/// Refund Status
enum RefundStatus { pending, succeeded, failed, cancelled }

/// Payment Method Type
enum PaymentMethodType { card, cash, bankTransfer, wallet }

/// Card Brand
enum CardBrand { visa, mastercard, amex, discover, jcb, unknown }

/// Payment Exception
class PaymentException implements Exception {
  final String message;

  PaymentException(this.message);

  @override
  String toString() => message;
}
