const express = require('express');
const router = express.Router();
const path = require('path');
const { authenticate } = require(path.join(__dirname, '../../../../shared/middleware/auth'));
const { buildRtcToken, ROLE_PUBLISHER, ROLE_SUBSCRIBER } = require('../utils/agoraToken');

// ---------------------------------------------------------------------------
// In-memory Agora token cache (no extra deps)
// Key: `${channelName}:${uid}:${roleCode}`
// Tokens are evicted 60 s before they expire to avoid serving near-dead tokens.
// ---------------------------------------------------------------------------
const _tokenCache = new Map();

function _getCached(key) {
  const entry = _tokenCache.get(key);
  if (!entry) return null;
  // 60-second safety buffer before expiry
  if (Math.floor(Date.now() / 1000) >= entry.expiresAt - 60) {
    _tokenCache.delete(key);
    return null;
  }
  return entry.token;
}

function _setCache(key, token, expireSeconds) {
  _tokenCache.set(key, {
    token,
    expiresAt: Math.floor(Date.now() / 1000) + expireSeconds,
  });
}

/**
 * POST /api/agora/token
 *
 * Generate a server-side Agora RTC AccessToken V2.
 * Requires a valid Firebase Bearer token.
 *
 * Body:
 *   channelName  {string}  Channel to join (required)
 *   uid          {number}  Agora numeric UID, 0 = auto-assign (optional, default 0)
 *   role         {string}  "publisher" | "subscriber" (optional, default "publisher")
 *   expireSeconds {number} Token TTL in seconds (optional, default 3600)
 */
router.post('/token', authenticate, (req, res) => {
  try {
    const appId = process.env.AGORA_APP_ID;
    const appCertificate = process.env.AGORA_APP_CERTIFICATE;

    if (!appId || !appCertificate) {
      return res.status(503).json({
        success: false,
        message: 'Agora is not configured on this server',
      });
    }

    const { channelName, uid = 0, role = 'publisher', expireSeconds = 3600 } = req.body;

    if (!channelName || typeof channelName !== 'string' || channelName.trim() === '') {
      return res.status(400).json({
        success: false,
        message: 'channelName is required',
      });
    }

    const roleCode = role === 'subscriber' ? ROLE_SUBSCRIBER : ROLE_PUBLISHER;
    const expire = Math.min(Math.max(parseInt(expireSeconds, 10) || 3600, 60), 86400); // 1 min – 24 h

    const cacheKey = `${channelName.trim()}:${uid}:${roleCode}`;
    const cached = _getCached(cacheKey);
    if (cached) {
      return res.json({
        success: true,
        data: { token: cached, channelName: channelName.trim(), uid, expireSeconds: expire },
      });
    }

    const token = buildRtcToken(
      appId,
      appCertificate,
      channelName.trim(),
      uid,
      roleCode,
      expire,
    );

    _setCache(cacheKey, token, expire);

    return res.json({
      success: true,
      data: {
        token,
        channelName: channelName.trim(),
        uid,
        expireSeconds: expire,
      },
    });
  } catch (err) {
    console.error('[Agora] token generation error:', err.message);
    return res.status(500).json({ success: false, message: 'Token generation failed' });
  }
});

module.exports = router;
