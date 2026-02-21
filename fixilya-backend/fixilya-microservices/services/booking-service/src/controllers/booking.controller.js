const { db } = require('../config/firebase');
const logger = require('../utils/logger');
const { sendNotification } = require('../services/notificationService');

// Create new booking
exports.createBooking = async (req, res, next) => {
  try {
    const clientId = req.user.uid;
    const {
      handymanId,
      serviceType,
      scheduledDate,
      address,
      notes,
      estimatedPrice
    } = req.body;

    // Validate required fields
    if (!handymanId || !serviceType || !scheduledDate || !address) {
      return res.status(400).json({
        success: false,
        message: 'Missing required fields',
      });
    }

    // Check if handyman exists and is available
    const handymanDoc = await db.collection('handymen').doc(handymanId).get();
    
    if (!handymanDoc.exists) {
      return res.status(404).json({
        success: false,
        message: 'Handyman not found',
      });
    }

    const handymanData = handymanDoc.data();
    
    if (!handymanData.isAvailable) {
      return res.status(400).json({
        success: false,
        message: 'Handyman is not available',
      });
    }

    // Create booking
    const bookingData = {
      clientId,
      handymanId,
      serviceType,
      scheduledDate: new Date(scheduledDate),
      address,
      notes: notes || '',
      estimatedPrice: estimatedPrice || null,
      status: 'pending',
      paymentStatus: 'pending',
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    const bookingRef = await db.collection('bookings').add(bookingData);

    // Get client data for notification
    const clientDoc = await db.collection('users').doc(clientId).get();
    const clientData = clientDoc.data();

    // Send notification to handyman
    await sendNotification({
      userId: handymanId,
      type: 'new_booking',
      title: 'New Booking Request',
      message: `${clientData.fullName} has requested a ${serviceType} service`,
      data: {
        bookingId: bookingRef.id,
        clientId,
        serviceType,
      },
    });

    logger.info(`Booking created: ${bookingRef.id}`);

    res.status(201).json({
      success: true,
      message: 'Booking created successfully',
      data: {
        bookingId: bookingRef.id,
        ...bookingData,
      },
    });
  } catch (error) {
    next(error);
  }
};

// Get all bookings for current user
exports.getMyBookings = async (req, res, next) => {
  try {
    const userId = req.user.uid;
    const { status, limit = 20, offset = 0 } = req.query;

    // Determine user type
    const userDoc = await db.collection('users').doc(userId).get();
    const userType = userDoc.data()?.userType;

    // Build query
    let query = db.collection('bookings');

    if (userType === 'client') {
      query = query.where('clientId', '==', userId);
    } else if (userType === 'handyman') {
      query = query.where('handymanId', '==', userId);
    }

    if (status) {
      query = query.where('status', '==', status);
    }

    query = query
      .orderBy('createdAt', 'desc')
      .limit(parseInt(limit))
      .offset(parseInt(offset));

    const snapshot = await query.get();

    const bookings = [];
    for (const doc of snapshot.docs) {
      const bookingData = doc.data();
      
      // Get client and handyman details
      const [clientDoc, handymanDoc] = await Promise.all([
        db.collection('users').doc(bookingData.clientId).get(),
        db.collection('handymen').doc(bookingData.handymanId).get(),
      ]);

      bookings.push({
        id: doc.id,
        ...bookingData,
        scheduledDate: bookingData.scheduledDate.toDate().toISOString(),
        createdAt: bookingData.createdAt.toDate().toISOString(),
        client: {
          name: clientDoc.data()?.fullName,
          phone: clientDoc.data()?.phone,
        },
        handyman: {
          name: handymanDoc.data()?.fullName,
          phone: handymanDoc.data()?.phone,
          rating: handymanDoc.data()?.rating,
        },
      });
    }

    res.json({
      success: true,
      data: {
        bookings,
        total: bookings.length,
      },
    });
  } catch (error) {
    next(error);
  }
};

// Get booking by ID
exports.getBooking = async (req, res, next) => {
  try {
    const { id } = req.params;
    const userId = req.user.uid;

    const bookingDoc = await db.collection('bookings').doc(id).get();

    if (!bookingDoc.exists) {
      return res.status(404).json({
        success: false,
        message: 'Booking not found',
      });
    }

    const bookingData = bookingDoc.data();

    // Verify user has access to this booking
    if (bookingData.clientId !== userId && bookingData.handymanId !== userId) {
      return res.status(403).json({
        success: false,
        message: 'Access denied',
      });
    }

    // Get full details
    const [clientDoc, handymanDoc] = await Promise.all([
      db.collection('users').doc(bookingData.clientId).get(),
      db.collection('handymen').doc(bookingData.handymanId).get(),
    ]);

    res.json({
      success: true,
      data: {
        id: bookingDoc.id,
        ...bookingData,
        scheduledDate: bookingData.scheduledDate.toDate().toISOString(),
        createdAt: bookingData.createdAt.toDate().toISOString(),
        client: {
          id: bookingData.clientId,
          name: clientDoc.data()?.fullName,
          phone: clientDoc.data()?.phone,
          profilePicture: clientDoc.data()?.profilePicture,
        },
        handyman: {
          id: bookingData.handymanId,
          name: handymanDoc.data()?.fullName,
          phone: handymanDoc.data()?.phone,
          rating: handymanDoc.data()?.rating,
          profilePicture: handymanDoc.data()?.profilePicture,
        },
      },
    });
  } catch (error) {
    next(error);
  }
};

// Update booking status
exports.updateBookingStatus = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { status } = req.body;
    const userId = req.user.uid;

    const validStatuses = ['pending', 'accepted', 'in_progress', 'completed', 'cancelled', 'rejected'];
    
    if (!validStatuses.includes(status)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid status',
      });
    }

    const bookingDoc = await db.collection('bookings').doc(id).get();

    if (!bookingDoc.exists) {
      return res.status(404).json({
        success: false,
        message: 'Booking not found',
      });
    }

    const bookingData = bookingDoc.data();

    // Verify user has permission to update
    const userDoc = await db.collection('users').doc(userId).get();
    const userType = userDoc.data()?.userType;

    if (userType === 'handyman' && bookingData.handymanId !== userId) {
      return res.status(403).json({
        success: false,
        message: 'Access denied',
      });
    }

    if (userType === 'client' && bookingData.clientId !== userId) {
      return res.status(403).json({
        success: false,
        message: 'Access denied',
      });
    }

    // Update booking
    await db.collection('bookings').doc(id).update({
      status,
      updatedAt: new Date(),
      ...(status === 'completed' && { completedDate: new Date() }),
    });

    // Send notification
    const notifyUserId = userType === 'handyman' ? bookingData.clientId : bookingData.handymanId;
    const notifyMessage = {
      accepted: 'Your booking has been accepted',
      rejected: 'Your booking has been rejected',
      in_progress: 'Your service is in progress',
      completed: 'Your service has been completed',
      cancelled: 'Booking has been cancelled',
    }[status];

    await sendNotification({
      userId: notifyUserId,
      type: 'booking_status_update',
      title: 'Booking Update',
      message: notifyMessage,
      data: { bookingId: id, status },
    });

    logger.info(`Booking ${id} status updated to ${status}`);

    res.json({
      success: true,
      message: 'Booking status updated',
      data: { status },
    });
  } catch (error) {
    next(error);
  }
};

// Cancel booking
exports.cancelBooking = async (req, res, next) => {
  try {
    const { id } = req.params;
    const userId = req.user.uid;

    const bookingDoc = await db.collection('bookings').doc(id).get();

    if (!bookingDoc.exists) {
      return res.status(404).json({
        success: false,
        message: 'Booking not found',
      });
    }

    const bookingData = bookingDoc.data();

    // Only client can cancel
    if (bookingData.clientId !== userId) {
      return res.status(403).json({
        success: false,
        message: 'Only the client can cancel this booking',
      });
    }

    // Can't cancel completed bookings
    if (bookingData.status === 'completed') {
      return res.status(400).json({
        success: false,
        message: 'Cannot cancel completed booking',
      });
    }

    await db.collection('bookings').doc(id).update({
      status: 'cancelled',
      updatedAt: new Date(),
    });

    // Notify handyman
    await sendNotification({
      userId: bookingData.handymanId,
      type: 'booking_cancelled',
      title: 'Booking Cancelled',
      message: 'A booking has been cancelled by the client',
      data: { bookingId: id },
    });

    logger.info(`Booking ${id} cancelled by client ${userId}`);

    res.json({
      success: true,
      message: 'Booking cancelled successfully',
    });
  } catch (error) {
    next(error);
  }
};