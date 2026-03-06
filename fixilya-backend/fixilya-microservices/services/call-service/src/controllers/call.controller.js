'use strict';

const path = require('path');
const callService = require('../services/call.service');
const { AppError } = require(path.join(__dirname, '../../../../shared/utils/appError'));
const audit = require(path.join(__dirname, '../../../../shared/utils/auditLogger'));

const callController = {

  /**
   * POST /api/calls/initiate
   * Body: { calleeId, callerName, calleeName, callerPicture?, calleePicture? }
   * Auth: Firebase JWT — caller identity comes from req.user.uid
   */
  async initiateCall(req, res, next) {
    try {
      const callerId = req.user.uid;
      const { calleeId, callerName, calleeName, callerPicture, calleePicture } = req.body;

      if (!calleeId || !callerName || !calleeName) {
        return res.status(400).json({
          success: false,
          message: 'calleeId, callerName, and calleeName are required',
        });
      }

      const { callId, callerToken } = await callService.initiateCall(callerId, {
        calleeId,
        callerName,
        calleeName,
        callerPicture,
        calleePicture,
      });

      audit.log('call-service', 'CALL_INITIATED', {
        callId,
        callerId,
        calleeId,
      });

      return res.status(201).json({
        success: true,
        data: { callId, callerToken },
      });
    } catch (err) {
      audit.error('call-service', 'CALL_INITIATE_FAILED', err, { uid: req.user?.uid });
      next(err);
    }
  },

  /**
   * GET /api/calls/:callId/accept
   * Auth: Firebase JWT — callee identity must match call.calleeId
   */
  async acceptCall(req, res, next) {
    try {
      const calleeUid = req.user.uid;
      const { callId } = req.params;

      if (!callId) {
        return res.status(400).json({ success: false, message: 'callId is required' });
      }

      const { calleeToken } = await callService.acceptCall(calleeUid, callId);

      audit.log('call-service', 'CALL_ACCEPTED', { callId, calleeUid });

      return res.status(200).json({
        success: true,
        data: { calleeToken },
      });
    } catch (err) {
      audit.error('call-service', 'CALL_ACCEPT_FAILED', err, { uid: req.user?.uid, callId: req.params?.callId });
      next(err);
    }
  },
};

module.exports = callController;
