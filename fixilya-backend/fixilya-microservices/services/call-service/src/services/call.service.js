'use strict';

const path = require('path');
const admin = require(path.join(__dirname, '../../../../shared/config/firebase'));
const { AppError } = require(path.join(__dirname, '../../../../shared/utils/appError'));
const logger = require(path.join(__dirname, '../../../../shared/utils/logger'));
const { buildRtcToken, ROLE_PUBLISHER } = require('../utils/agoraToken');

const db = admin.firestore();
const CALLS_COLLECTION = 'calls';
const BOOKINGS_COLLECTION = 'bookings';

// Token TTL: 1 hour, clamped between 60 s and 24 h
const TOKEN_TTL = 3600;

class CallService {
  // ─────────────────────────────────────────────
  // INITIATE
  // ─────────────────────────────────────────────

  /**
   * Creates a new call session.
   *
   * Security:
   * - Verifies callerId and calleeId share a confirmed/in_progress booking.
   * - Generates caller Agora token server-side (never client-generated).
   * - Server writes the Firestore call doc (client cannot forge calls).
   *
   * @param {string} callerId  Firebase UID of the caller
   * @param {object} opts
   * @param {string} opts.calleeId
   * @param {string} opts.callerName
   * @param {string} opts.calleeName
   * @param {string} [opts.callerPicture]
   * @param {string} [opts.calleePicture]
   * @returns {{ callId: string, callerToken: string }}
   */
  async initiateCall(callerId, { calleeId, callerName, calleeName, callerPicture, calleePicture }) {
    const appId = process.env.AGORA_APP_ID;
    const appCert = process.env.AGORA_APP_CERTIFICATE;

    if (!appId || !appCert) {
      throw new AppError('Agora is not configured on this server', 503);
    }

    if (!calleeId || calleeId === callerId) {
      throw new AppError('Invalid callee', 400);
    }

    // ── Booking authorization ──────────────────────────────────────────────
    // Check both directions: client→handyman and handyman→client
    const [q1, q2] = await Promise.all([
      db.collection(BOOKINGS_COLLECTION)
        .where('clientId',   '==', callerId)
        .where('handymanId', '==', calleeId)
        .where('status', 'in', ['confirmed', 'in_progress'])
        .limit(1)
        .get(),
      db.collection(BOOKINGS_COLLECTION)
        .where('handymanId', '==', callerId)
        .where('clientId',   '==', calleeId)
        .where('status', 'in', ['confirmed', 'in_progress'])
        .limit(1)
        .get(),
    ]);

    if (q1.empty && q2.empty) {
      logger.warn(`[CallService.initiateCall] No active booking between ${callerId} and ${calleeId}`);
      throw new AppError('No active booking found between caller and callee', 403);
    }

    // ── Generate caller token ──────────────────────────────────────────────
    const callDoc = db.collection(CALLS_COLLECTION).doc();
    const callId = callDoc.id;

    const callerToken = buildRtcToken(appId, appCert, callId, 0, ROLE_PUBLISHER, TOKEN_TTL);

    // ── Write call document (server-side only) ────────────────────────────
    await callDoc.set({
      callId,
      callerId,
      calleeId,
      callerName:    callerName   || 'Caller',
      calleeName:    calleeName   || 'Callee',
      callerPicture: callerPicture || null,
      calleePicture: calleePicture || null,
      channelName:   callId,  // Agora channel name == call document ID
      status:        'ringing',
      createdAt:     admin.firestore.FieldValue.serverTimestamp(),
      updatedAt:     admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info(`[CallService.initiateCall] callId=${callId} caller=${callerId} callee=${calleeId}`);

    return { callId, callerToken };
  }

  // ─────────────────────────────────────────────
  // ACCEPT
  // ─────────────────────────────────────────────

  /**
   * Validates the callee, transitions status to 'active', and returns
   * a fresh Agora token for the callee to join the channel.
   *
   * Security:
   * - Verifies req.uid === call.calleeId (enforced by controller).
   * - Returns 404 if call not found, 409 if already active/ended.
   * - Generates a brand-new token — nothing sensitive is stored in Firestore.
   *
   * @param {string} calleeUid  Firebase UID from verified JWT
   * @param {string} callId     Firestore document ID
   * @returns {{ calleeToken: string }}
   */
  async acceptCall(calleeUid, callId) {
    const appId = process.env.AGORA_APP_ID;
    const appCert = process.env.AGORA_APP_CERTIFICATE;

    if (!appId || !appCert) {
      throw new AppError('Agora is not configured on this server', 503);
    }

    const callSnap = await db.collection(CALLS_COLLECTION).doc(callId).get();
    if (!callSnap.exists) {
      throw new AppError('Call not found', 404);
    }

    const call = callSnap.data();

    if (call.calleeId !== calleeUid) {
      throw new AppError('Forbidden', 403);
    }

    if (call.status !== 'ringing') {
      throw new AppError(`Call is already ${call.status}`, 409);
    }

    // Generate a fresh callee token — never stored in Firestore
    const calleeToken = buildRtcToken(appId, appCert, callId, 0, ROLE_PUBLISHER, TOKEN_TTL);

    await db.collection(CALLS_COLLECTION).doc(callId).update({
      status:    'active',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info(`[CallService.acceptCall] callId=${callId} callee=${calleeUid} → active`);

    return { calleeToken };
  }
}

module.exports = new CallService();
