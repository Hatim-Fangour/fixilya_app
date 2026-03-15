/// Data Models - Booking Model
/// Comprehensive booking/appointment data model
///
library;
import 'package:cloud_firestore/cloud_firestore.dart';

enum BookingStatus {
  pending,
  confirmed,
  inProgress,
  completed,
  cancelled,
  refunded,
}

enum PaymentStatus { unpaid, paid, partiallyPaid, refunded }

enum PaymentMethod { cash, card, bankTransfer, wallet }

class BookingModel {
  final String id;
  final String clientId;
  final String handymanId;
  final String serviceType;
  final String? serviceDescription;
  final DateTime scheduledDate;
  final String scheduledTime;
  final int estimatedDuration; // in minutes
  final String location;
  final String? address;
  final double? latitude;
  final double? longitude;
  final double hourlyRate;
  final double? estimatedCost;
  final double? actualCost;
  final double? discount;
  final double? tax;
  final double? totalCost;
  final BookingStatus status;
  final PaymentStatus paymentStatus;
  final PaymentMethod? paymentMethod;
  final String? paymentTransactionId;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? clientNotes;
  final String? handymanNotes;
  final String? cancellationReason;
  final String? cancelledBy; // clientId or handymanId
  final DateTime? cancelledAt;
  final List<String> attachments;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;

  BookingModel({
    required this.id,
    required this.clientId,
    required this.handymanId,
    required this.serviceType,
    this.serviceDescription,
    required this.scheduledDate,
    required this.scheduledTime,
    this.estimatedDuration = 60,
    required this.location,
    this.address,
    this.latitude,
    this.longitude,
    required this.hourlyRate,
    this.estimatedCost,
    this.actualCost,
    this.discount,
    this.tax,
    this.totalCost,
    this.status = BookingStatus.pending,
    this.paymentStatus = PaymentStatus.unpaid,
    this.paymentMethod,
    this.paymentTransactionId,
    this.startTime,
    this.endTime,
    this.clientNotes,
    this.handymanNotes,
    this.cancellationReason,
    this.cancelledBy,
    this.cancelledAt,
    this.attachments = const [],
    required this.createdAt,
    required this.updatedAt,
    this.metadata,
  });

  // ==================== Factory Constructors ====================

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id'] ?? '',
      clientId: json['clientId'] ?? '',
      handymanId: json['handymanId'] ?? '',
      serviceType: json['serviceType'] ?? '',
      serviceDescription: json['serviceDescription'],
      scheduledDate: _parseDateTime(json['scheduledDate']),
      scheduledTime: json['scheduledTime'] ?? '',
      estimatedDuration: json['estimatedDuration'] ?? 60,
      location: json['location'] ?? '',
      address: json['address'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      hourlyRate: (json['hourlyRate'] ?? 0).toDouble(),
      estimatedCost: json['estimatedCost']?.toDouble(),
      actualCost: json['actualCost']?.toDouble(),
      discount: json['discount']?.toDouble(),
      tax: json['tax']?.toDouble(),
      totalCost: json['totalCost']?.toDouble(),
      status: _parseBookingStatus(json['status']),
      paymentStatus: _parsePaymentStatus(json['paymentStatus']),
      paymentMethod: _parsePaymentMethod(json['paymentMethod']),
      paymentTransactionId: json['paymentTransactionId'],
      startTime: json['startTime'] != null
          ? _parseDateTime(json['startTime'])
          : null,
      endTime: json['endTime'] != null ? _parseDateTime(json['endTime']) : null,
      clientNotes: json['clientNotes'],
      handymanNotes: json['handymanNotes'],
      cancellationReason: json['cancellationReason'],
      cancelledBy: json['cancelledBy'],
      cancelledAt: json['cancelledAt'] != null
          ? _parseDateTime(json['cancelledAt'])
          : null,
      attachments: List<String>.from(json['attachments'] ?? []),
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  factory BookingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Document data is null');
    }

    return BookingModel.fromJson({...data, 'id': doc.id});
  }

  factory BookingModel.empty() {
    return BookingModel(
      id: '',
      clientId: '',
      handymanId: '',
      serviceType: '',
      scheduledDate: DateTime.now(),
      scheduledTime: '',
      location: '',
      hourlyRate: 0.0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // ==================== Conversion Methods ====================

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'clientId': clientId,
      'handymanId': handymanId,
      'serviceType': serviceType,
      'serviceDescription': serviceDescription,
      'scheduledDate': scheduledDate.toIso8601String(),
      'scheduledTime': scheduledTime,
      'estimatedDuration': estimatedDuration,
      'location': location,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'hourlyRate': hourlyRate,
      'estimatedCost': estimatedCost,
      'actualCost': actualCost,
      'discount': discount,
      'tax': tax,
      'totalCost': totalCost,
      'status': status.name,
      'paymentStatus': paymentStatus.name,
      'paymentMethod': paymentMethod?.name,
      'paymentTransactionId': paymentTransactionId,
      'startTime': startTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'clientNotes': clientNotes,
      'handymanNotes': handymanNotes,
      'cancellationReason': cancellationReason,
      'cancelledBy': cancelledBy,
      'cancelledAt': cancelledAt?.toIso8601String(),
      'attachments': attachments,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'metadata': metadata,
    };
    // Remove null fields to keep Firestore documents clean
    map.removeWhere((key, value) => value == null);
    return map;
  }

  Map<String, dynamic> toFirestore() {
    final json = toJson();
    json.remove('id');
    return json;
  }

  // ==================== Copy With ====================

  BookingModel copyWith({
    String? id,
    String? clientId,
    String? handymanId,
    String? serviceType,
    String? serviceDescription,
    DateTime? scheduledDate,
    String? scheduledTime,
    int? estimatedDuration,
    String? location,
    String? address,
    double? latitude,
    double? longitude,
    double? hourlyRate,
    double? estimatedCost,
    double? actualCost,
    double? discount,
    double? tax,
    double? totalCost,
    BookingStatus? status,
    PaymentStatus? paymentStatus,
    PaymentMethod? paymentMethod,
    String? paymentTransactionId,
    DateTime? startTime,
    DateTime? endTime,
    String? clientNotes,
    String? handymanNotes,
    String? cancellationReason,
    String? cancelledBy,
    DateTime? cancelledAt,
    List<String>? attachments,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return BookingModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      handymanId: handymanId ?? this.handymanId,
      serviceType: serviceType ?? this.serviceType,
      serviceDescription: serviceDescription ?? this.serviceDescription,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      location: location ?? this.location,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      actualCost: actualCost ?? this.actualCost,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      totalCost: totalCost ?? this.totalCost,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentTransactionId: paymentTransactionId ?? this.paymentTransactionId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      clientNotes: clientNotes ?? this.clientNotes,
      handymanNotes: handymanNotes ?? this.handymanNotes,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  // ==================== Helper Methods ====================

  bool get isPending => status == BookingStatus.pending;
  bool get isConfirmed => status == BookingStatus.confirmed;
  bool get isInProgress => status == BookingStatus.inProgress;
  bool get isCompleted => status == BookingStatus.completed;
  bool get isCancelled => status == BookingStatus.cancelled;

  bool get isPaid => paymentStatus == PaymentStatus.paid;
  bool get isUnpaid => paymentStatus == PaymentStatus.unpaid;

  bool get isUpcoming {
    final now = DateTime.now();
    return scheduledDate.isAfter(now) && !isCancelled && !isCompleted;
  }

  bool get isPast {
    final now = DateTime.now();
    return scheduledDate.isBefore(now) || isCompleted || isCancelled;
  }

  bool get canBeCancelled {
    if (isCancelled || isCompleted) return false;

    final now = DateTime.now();
    final timeUntilBooking = scheduledDate.difference(now);

    // Can cancel if booking is more than 24 hours away
    return timeUntilBooking.inHours >= 24;
  }

  int? get actualDuration {
    if (startTime != null && endTime != null) {
      return endTime!.difference(startTime!).inMinutes;
    }
    return null;
  }

  String get statusText {
    switch (status) {
      case BookingStatus.pending:
        return 'Pending Confirmation';
      case BookingStatus.confirmed:
        return 'Confirmed';
      case BookingStatus.inProgress:
        return 'In Progress';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.cancelled:
        return 'Cancelled';
      case BookingStatus.refunded:
        return 'Refunded';
    }
  }

  // ==================== Static Helpers ====================

  static BookingStatus _parseBookingStatus(dynamic value) {
    if (value == null) return BookingStatus.pending;
    if (value is BookingStatus) return value;

    switch (value.toString().toLowerCase()) {
      case 'confirmed':
        return BookingStatus.confirmed;
      case 'inprogress':
      case 'in_progress':
        return BookingStatus.inProgress;
      case 'completed':
        return BookingStatus.completed;
      case 'cancelled':
        return BookingStatus.cancelled;
      case 'refunded':
        return BookingStatus.refunded;
      case 'pending':
      default:
        return BookingStatus.pending;
    }
  }

  static PaymentStatus _parsePaymentStatus(dynamic value) {
    if (value == null) return PaymentStatus.unpaid;
    if (value is PaymentStatus) return value;

    switch (value.toString().toLowerCase()) {
      case 'paid':
        return PaymentStatus.paid;
      case 'partiallypaid':
      case 'partially_paid':
        return PaymentStatus.partiallyPaid;
      case 'refunded':
        return PaymentStatus.refunded;
      case 'unpaid':
      default:
        return PaymentStatus.unpaid;
    }
  }

  static PaymentMethod? _parsePaymentMethod(dynamic value) {
    if (value == null) return null;
    if (value is PaymentMethod) return value;

    switch (value.toString().toLowerCase()) {
      case 'cash':
        return PaymentMethod.cash;
      case 'card':
        return PaymentMethod.card;
      case 'banktransfer':
      case 'bank_transfer':
        return PaymentMethod.bankTransfer;
      case 'wallet':
        return PaymentMethod.wallet;
      default:
        return null;
    }
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }

  // ==================== Equality ====================

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookingModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'BookingModel{id: $id, status: ${status.name}, scheduledDate: $scheduledDate}';
  }
}
