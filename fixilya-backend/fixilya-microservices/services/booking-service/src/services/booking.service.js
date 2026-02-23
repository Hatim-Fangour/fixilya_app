const { getPrismaClient } = require('../../../../shared/config/database');
const { publishEvent } = require('../../../../shared/config/redis');
const { AppError } = require('../../../../shared/middleware/errorHandler');
const { createServiceLogger } = require('../../../../shared/utils/logger');

const logger = createServiceLogger('booking-service');

// Redis event channels
const EVENTS = {
  BOOKING_CREATED: 'booking:created',
  BOOKING_CONFIRMED: 'booking:confirmed',
  BOOKING_CANCELLED: 'booking:cancelled',
  BOOKING_COMPLETED: 'booking:completed',
};

// Valid status transitions
const STATUS_TRANSITIONS = {
  pending: ['confirmed', 'cancelled'],
  confirmed: ['in_progress', 'cancelled'],
  in_progress: ['completed', 'disputed'],
  completed: [],
  cancelled: [],
  disputed: ['resolved', 'cancelled'],
};

class BookingService {
  constructor() {
    this.prisma = getPrismaClient();
  }

  async createBooking(clientUid, data) {
    const { providerId, categoryId, description, scheduledAt, address } = data;

    // Verify provider exists and is available (call user-service via HTTP in prod)
    const booking = await this.prisma.booking.create({
      data: {
        clientUid,
        providerId,
        categoryId,
        description,
        scheduledAt: new Date(scheduledAt),
        status: 'pending',
        address: {
          create: {
            street: address.street,
            city: address.city,
            region: address.region,
            lat: address.lat,
            lng: address.lng,
          },
        },
      },
      include: { address: true },
    });

    // Notify provider via Redis event
    await publishEvent(EVENTS.BOOKING_CREATED, {
      bookingId: booking.id,
      clientUid,
      providerId,
      scheduledAt,
      categoryId,
    });

    logger.info('Booking created', { bookingId: booking.id, clientUid, providerId });
    return booking;
  }

  async getBookingById(bookingId, uid, role) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: { address: true, review: true, payments: true },
    });

    if (!booking) throw new AppError('Booking not found', 404, 'BOOKING_NOT_FOUND');

    // Access control: clients/providers can only see their own bookings
    const isOwner = booking.clientUid === uid || booking.providerId === uid;
    if (role !== 'admin' && !isOwner) {
      throw new AppError('Access denied', 403, 'FORBIDDEN');
    }

    return booking;
  }

  async getUserBookings(uid, role, { status, page = 1, limit = 20 }) {
    const skip = (page - 1) * limit;
    const where = {
      ...(status && { status }),
      ...(role === 'client' ? { clientUid: uid } : { providerId: uid }),
    };

    const [bookings, total] = await this.prisma.$transaction([
      this.prisma.booking.findMany({
        where,
        include: { address: true },
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.booking.count({ where }),
    ]);

    return { bookings, total, page, limit, pages: Math.ceil(total / limit) };
  }

  async updateStatus(bookingId, uid, role, newStatus, reason) {
    const booking = await this.prisma.booking.findUnique({ where: { id: bookingId } });
    if (!booking) throw new AppError('Booking not found', 404, 'BOOKING_NOT_FOUND');

    const isClient = booking.clientUid === uid;
    const isProvider = booking.providerId === uid;
    if (role !== 'admin' && !isClient && !isProvider) {
      throw new AppError('Access denied', 403, 'FORBIDDEN');
    }

    const allowed = STATUS_TRANSITIONS[booking.status] || [];
    if (!allowed.includes(newStatus)) {
      throw new AppError(
        `Cannot transition from '${booking.status}' to '${newStatus}'`,
        400,
        'INVALID_STATUS_TRANSITION'
      );
    }

    const updated = await this.prisma.booking.update({
      where: { id: bookingId },
      data: {
        status: newStatus,
        ...(reason && { cancellationReason: reason }),
        ...(newStatus === 'completed' && { completedAt: new Date() }),
      },
    });

    // Publish status change event for notification-service & payment-service
    const eventMap = {
      confirmed: EVENTS.BOOKING_CONFIRMED,
      cancelled: EVENTS.BOOKING_CANCELLED,
      completed: EVENTS.BOOKING_COMPLETED,
    };

    if (eventMap[newStatus]) {
      await publishEvent(eventMap[newStatus], {
        bookingId,
        clientUid: booking.clientUid,
        providerId: booking.providerId,
        newStatus,
        reason,
      });
    }

    logger.info('Booking status updated', { bookingId, from: booking.status, to: newStatus });
    return updated;
  }

  async submitReview(bookingId, clientUid, { rating, comment }) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: { review: true },
    });

    if (!booking) throw new AppError('Booking not found', 404, 'BOOKING_NOT_FOUND');
    if (booking.clientUid !== clientUid) throw new AppError('Access denied', 403, 'FORBIDDEN');
    if (booking.status !== 'completed') throw new AppError('Can only review completed bookings', 400, 'INVALID_STATUS');
    if (booking.review) throw new AppError('Review already submitted', 409, 'REVIEW_EXISTS');

    const review = await this.prisma.review.create({
      data: {
        bookingId,
        reviewerUid: clientUid,
        revieweeUid: booking.providerId,
        rating,
        comment,
      },
    });

    logger.info('Review submitted', { bookingId, rating });
    return review;
  }
}

module.exports = new BookingService();