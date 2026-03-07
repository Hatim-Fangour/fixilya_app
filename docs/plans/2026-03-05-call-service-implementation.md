# Call Service Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a dedicated `call-service` (Node.js/Express, port 3007) that securely manages in-app voice calls between clients and handymen, with booking-link authorization and per-identity Agora token generation.

**Architecture:** New call-service sits behind Nginx at `/api/calls`. It validates that caller and callee share an active booking before allowing a call. The server writes the Firestore `/calls` doc (not the client), generates the caller's Agora token at call creation and the callee's token on-demand at accept time (never stored in Firestore). Flutter `CallService` posts to call-service instead of writing Firestore directly.

**Tech Stack:** Node.js 18+, Express, firebase-admin (Firestore), Agora AccessToken V2 (custom implementation — no npm package needed, copy from auth-service), Flutter + Dio, Firestore real-time streams.

---

### Task 1: Create call-service directory structure and package.json

**Files:**
- Create: `fixilya-backend/fixilya-microservices/services/call-service/package.json`
- Create: `fixilya-backend/fixilya-microservices/services/call-service/src/app.js` (empty placeholder)
- Create: `fixilya-backend/fixilya-microservices/services/call-service/src/routes/call.routes.js` (empty placeholder)
- Create: `fixilya-backend/fixilya-microservices/services/call-service/src/controllers/call.controller.js` (empty placeholder)
- Create: `fixilya-backend/fixilya-microservices/services/call-service/src/services/call.service.js` (empty placeholder)
- Create: `fixilya-backend/fixilya-microservices/services/call-service/src/utils/agoraToken.js` (empty placeholder)
- Create: `fixilya-backend/fixilya-microservices/services/call-service/.env`

**Step 1: Create package.json**

```json
{
  "name": "call-service",
  "version": "1.0.0",
  "description": "Fixilya in-app call service — Agora RTC token generation with booking authorization",
  "main": "src/app.js",
  "scripts": {
    "start": "node src/app.js",
    "dev":   "nodemon src/app.js"
  },
  "dependencies": {
    "cors":               "^2.8.5",
    "dotenv":             "^16.4.5",
    "express":            "^4.18.3",
    "express-rate-limit": "^7.2.0",
    "firebase-admin":     "^12.0.0",
    "helmet":             "^7.1.0",
    "morgan":             "^1.10.0",
    "winston":            "^3.11.0"
  },
  "devDependencies": {
    "nodemon": "^3.1.0"
  },
  "engines": {
    "node": ">=18.0.0"
  }
}
```

**Step 2: Create .env**

```env
PORT=3007
NODE_ENV=development

# Firebase — copy values from auth-service/.env
FIREBASE_PROJECT_ID=fixilyaapp-10ca8
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-fbsvc@fixilyaapp-10ca8.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"

# Agora — copy values from auth-service/.env
AGORA_APP_ID=100dfbc4a86d4affbe7eaabe0808a6d8
AGORA_APP_CERTIFICATE=f4101819d51c4f5083a1fee52ad2fada
```

**Step 3: Create empty placeholder files for the directory structure**

```
mkdir -p fixilya-backend/fixilya-microservices/services/call-service/src/routes
mkdir -p fixilya-backend/fixilya-microservices/services/call-service/src/controllers
mkdir -p fixilya-backend/fixilya-microservices/services/call-service/src/services
mkdir -p fixilya-backend/fixilya-microservices/services/call-service/src/utils
```

**Step 4: Install dependencies**

```bash
cd fixilya-backend/fixilya-microservices/services/call-service
npm install
```

**Step 5: Commit**

```bash
git add fixilya-backend/fixilya-microservices/services/call-service/package.json
git add fixilya-backend/fixilya-microservices/services/call-service/.env
git commit -m "feat(call-service): scaffold call-service package.json"
```

---

### Task 2: Copy agoraToken utility to call-service

**Files:**
- Create: `fixilya-backend/fixilya-microservices/services/call-service/src/utils/agoraToken.js`

The Agora token builder is a self-contained file with no npm dependencies. Copy it verbatim from auth-service.

**Step 1: Copy the file**

The source is `fixilya-backend/fixilya-microservices/services/auth-service/src/utils/agoraToken.js`.
Copy it exactly to `fixilya-backend/fixilya-microservices/services/call-service/src/utils/agoraToken.js`.
No modifications needed — the file exports `{ buildRtcToken, ROLE_PUBLISHER, ROLE_SUBSCRIBER }`.

**Step 2: Commit**

```bash
git add fixilya-backend/fixilya-microservices/services/call-service/src/utils/agoraToken.js
git commit -m "feat(call-service): add Agora RTC token builder utility"
```

---

### Task 3: Implement call.service.js — core business logic

**Files:**
- Create: `fixilya-backend/fixilya-microservices/services/call-service/src/services/call.service.js`

This is the most important file. It:
1. Runs a booking authorization check (caller and callee must share a confirmed/in_progress booking)
2. Generates a caller Agora token (returned to Flutter)
3. Writes the call document to Firestore
4. On accept: validates callee identity, generates a fresh callee token, sets status → active

**Step 1: Write call.service.js**

```javascript
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
```

**Step 2: Commit**

```bash
git add fixilya-backend/fixilya-microservices/services/call-service/src/services/call.service.js
git commit -m "feat(call-service): implement CallService with booking auth and Agora token gen"
```

---

### Task 4: Implement call.controller.js and call.routes.js

**Files:**
- Create: `fixilya-backend/fixilya-microservices/services/call-service/src/controllers/call.controller.js`
- Create: `fixilya-backend/fixilya-microservices/services/call-service/src/routes/call.routes.js`

**Step 1: Write call.controller.js**

```javascript
'use strict';

const path = require('path');
const callService = require('../services/call.service');
const { AppError } = require(path.join(__dirname, '../../../../shared/utils/appError'));
const audit = require(path.join(__dirname, '../../../../shared/utils/auditLogger'));

const callController = {

  /**
   * POST /api/calls/initiate
   *
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
   *
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
```

**Step 2: Write call.routes.js**

```javascript
'use strict';

const express = require('express');
const router = express.Router();
const path = require('path');
const { authenticate } = require(path.join(__dirname, '../../../../shared/middleware/auth'));
const rateLimit = require('express-rate-limit');
const callController = require('../controllers/call.controller');

// Strict rate limit for call initiation: 10 calls per minute per IP
const callInitiateLimit = rateLimit({
  windowMs: 60 * 1000,
  max: 10,
  message: { success: false, message: 'Too many call requests, please wait' },
  standardHeaders: true,
  legacyHeaders: false,
});

// POST /api/calls/initiate
router.post('/initiate', callInitiateLimit, authenticate, callController.initiateCall);

// GET /api/calls/:callId/accept
router.get('/:callId/accept', authenticate, callController.acceptCall);

module.exports = router;
```

**Step 3: Commit**

```bash
git add fixilya-backend/fixilya-microservices/services/call-service/src/controllers/call.controller.js
git add fixilya-backend/fixilya-microservices/services/call-service/src/routes/call.routes.js
git commit -m "feat(call-service): add call controller and routes"
```

---

### Task 5: Implement call-service app.js

**Files:**
- Create: `fixilya-backend/fixilya-microservices/services/call-service/src/app.js`

This follows the exact same pattern as auth-service/src/app.js.

**Step 1: Write app.js**

```javascript
'use strict';

require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

const path = require('path');
const validateEnv = require(path.join(__dirname, '../../../shared/config/validateEnv'));
validateEnv(['FIREBASE_PROJECT_ID', 'AGORA_APP_ID', 'AGORA_APP_CERTIFICATE']);

const express = require('express');
const helmet  = require('helmet');
const cors    = require('cors');
const morgan  = require('morgan');

const logger        = require(path.join(__dirname, '../../../shared/utils/logger'));
const requestLogger = require(path.join(__dirname, '../../../shared/middleware/requestLogger'));
const { AppError }  = require(path.join(__dirname, '../../../shared/utils/appError'));
const corsOptions   = require(path.join(__dirname, '../../../shared/config/cors'));

const app  = express();
const PORT = process.env.PORT || 3007;

// ── Middleware ────────────────────────────────────────────────────────────────
app.use(helmet());
app.use(cors(corsOptions()));
app.use(express.json());
app.use(requestLogger('call-service'));
app.use(morgan('combined', {
  stream: { write: (msg) => logger.info(msg.trim()) },
}));

// ── Health check ──────────────────────────────────────────────────────────────
app.get('/health', (req, res) => {
  res.json({
    service:   'call-service',
    status:    'healthy',
    port:      PORT,
    timestamp: new Date().toISOString(),
  });
});

// ── Routes ────────────────────────────────────────────────────────────────────
const callRoutes = require('./routes/call.routes');
app.use('/api/calls', callRoutes);

// ── Error handler ─────────────────────────────────────────────────────────────
app.use((err, req, res, next) => {
  logger.error('call-service error:', err);

  if (err instanceof AppError && err.isOperational) {
    return res.status(err.statusCode).json({
      success: false,
      message: err.message,
    });
  }

  res.status(500).json({ success: false, message: 'Internal server error' });
});

app.listen(PORT, () => {
  logger.info(`📞 Call Service running on port ${PORT}`);
  console.log(`📞 Call Service running on port ${PORT}`);
});

module.exports = app;
```

**Step 2: Verify it starts (no Docker needed, just local)**

```bash
cd fixilya-backend/fixilya-microservices/services/call-service
npm start
```

Expected output: `📞 Call Service running on port 3007`

Press Ctrl+C after confirming it starts.

**Step 3: Commit**

```bash
git add fixilya-backend/fixilya-microservices/services/call-service/src/app.js
git commit -m "feat(call-service): add Express app entry point"
```

---

### Task 6: Update nginx.conf and docker-compose.yml

**Files:**
- Modify: `fixilya-backend/fixilya-microservices/gateway/nginx.conf`
- Modify: `fixilya-backend/fixilya-microservices/docker-compose.yml`

**Step 1: Add call_service upstream and location in nginx.conf**

After the `media_service` upstream block (around line 28), add:

```nginx
    upstream call_service {
        server call-service:3007;
    }
```

Add a new `call_limit` rate limit zone alongside the existing `api_limit` zone (after line 32):

```nginx
    limit_req_zone $binary_remote_addr zone=call_limit:10m rate=10r/m;
```

Add the location block after the media service block (before the closing `}`):

```nginx
        # Call Service
        location /api/calls {
            limit_req zone=call_limit burst=5 nodelay;
            proxy_pass http://call_service;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }
```

**Step 2: Add call-service to docker-compose.yml**

After the `media-service` block (around line 127), add:

```yaml
  # Call Service
  call-service:
    build:
      context: ./services/call-service
    container_name: call-service
    environment:
      - PORT=3007
      - NODE_ENV=production
    env_file:
      - ./services/call-service/.env
    ports:
      - "3007:3007"
    depends_on:
      - redis
    networks:
      - fixilya-network
    restart: unless-stopped
```

Also add `call-service` to the nginx `depends_on` list.

**Step 3: Commit**

```bash
git add fixilya-backend/fixilya-microservices/gateway/nginx.conf
git add fixilya-backend/fixilya-microservices/docker-compose.yml
git commit -m "feat(call-service): add nginx routing and docker-compose entry for call-service"
```

---

### Task 7: Update Flutter AppConfig and ApiClient

**Files:**
- Modify: `lib/core/config/app_config.dart`
- Modify: `lib/services/api_client.dart`

**Step 1: Add callServiceUrl to app_config.dart**

In `app_config.dart`, after the `notificationServiceUrl` constant (around line 33), add:

```dart
  static const String callServiceUrl = String.fromEnvironment(
    'CALL_SERVICE_URL',
    defaultValue: 'http://10.0.2.2:3007/api',
  );
```

**Step 2: Add callDio to api_client.dart**

In `api_client.dart`:

After line 19 (`late final Dio notificationDio;`), add:
```dart
  late final Dio callDio;
```

After line 26 (`static String get _notificationServiceUrl => AppConfig.notificationServiceUrl;`), add:
```dart
  static String get _callServiceUrl => AppConfig.callServiceUrl;
```

After line 65 (`notificationDio = _createDio(_notificationServiceUrl);`), add:
```dart
    // Call Service Dio
    callDio = _createDio(_callServiceUrl);
```

**Step 3: Commit**

```bash
git add lib/core/config/app_config.dart
git add lib/services/api_client.dart
git commit -m "feat(call-service): add callServiceUrl config and callDio to ApiClient"
```

---

### Task 8: Rewrite call_service.dart (Flutter)

**Files:**
- Modify: `lib/services/call_service.dart`

The current `initiateCall` writes to Firestore directly. Rewrite it to call the call-service API.
The current `acceptCall` only updates Firestore status. Rewrite it to fetch the callee token from the server.

**Step 1: Rewrite the `initiateCall` method**

Replace the entire `initiateCall` method (lines 72–98) with:

```dart
  /// Creates a call session via call-service.
  ///
  /// The server validates that caller and callee share an active booking,
  /// writes the Firestore call doc, and returns the caller's Agora token.
  ///
  /// Returns `{'callId': String, 'token': String?}`.
  Future<Map<String, String?>> initiateCall({
    required String calleeId,
    required String calleeName,
    required String callerName,
    String? calleePicture,
    String? callerPicture,
  }) async {
    try {
      final response = await ApiClient().callDio.post(
        '/calls/initiate',
        data: {
          'calleeId':      calleeId,
          'calleeName':    calleeName,
          'callerName':    callerName,
          if (calleePicture != null) 'calleePicture': calleePicture,
          if (callerPicture != null) 'callerPicture': callerPicture,
        },
      );
      if (response.statusCode == 201 && response.data['success'] == true) {
        final data = response.data['data'] as Map<String, dynamic>;
        return {
          'callId': data['callId'] as String,
          'token':  data['callerToken'] as String?,
        };
      }
      throw Exception('Unexpected response from call-service: ${response.statusCode}');
    } on DioException catch (e) {
      debugLog('initiateCall error: ${e.type} — ${e.response?.data}');
      rethrow;
    }
  }
```

**Step 2: Replace the `acceptCall` method**

Replace the `acceptCall` method (lines 101–106) with:

```dart
  /// Fetches the callee's Agora token from call-service (also sets status → active).
  ///
  /// Returns the Agora token string, or null if the request fails.
  Future<String?> acceptCall(String callId) async {
    try {
      final response = await ApiClient().callDio.get('/calls/$callId/accept');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data']['calleeToken'] as String?;
      }
      return null;
    } on DioException catch (e) {
      debugLog('acceptCall error: ${e.type}');
      return null;
    }
  }
```

**Step 3: Remove the `fetchAgoraToken` method** (lines 47–62)

It is no longer called. Delete it.

**Step 4: Remove the `agoraAppId` getter and `AGORA CONFIG` section** (lines 33–38)

`CallScreen` reads `CallService.agoraAppId` — keep the getter but it now reads from `AppConfig` directly (no change needed if it already does).

Actually, check line 37: `static String get agoraAppId => AppConfig.agoraAppId;` — keep this, `CallScreen` still needs it.

**Step 5: Commit**

```bash
git add lib/services/call_service.dart
git commit -m "feat(call-service): route call initiation and accept through call-service API"
```

---

### Task 9: Fix IncomingCallScreen — fetch callee Agora token on accept

**Files:**
- Modify: `lib/features/call/presentation/screens/incoming_call_screen.dart`

**Problem:** The current `_accept()` calls `_callService.acceptCall(callId)` (which now returns `String?` token), but ignores the return value and navigates to `CallScreen` with `agoraToken: null`.

**Step 1: Update `_accept()` in incoming_call_screen.dart (around line 76)**

Replace:
```dart
  Future<void> _accept() async {
    if (_responded) return;
    _responded = true;
    _missedTimer?.cancel();
    await _callService.acceptCall(widget.callId);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          callId: widget.callId,
          remoteUid: '',
          remoteName: widget.callerName,
          remotePicture: widget.callerPicture,
          isCaller: false,
        ),
      ),
    );
  }
```

With:
```dart
  Future<void> _accept() async {
    if (_responded) return;
    _responded = true;
    _missedTimer?.cancel();

    // Fetch callee Agora token from server; also transitions call status → active.
    final calleeToken = await _callService.acceptCall(widget.callId);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          callId: widget.callId,
          remoteUid: '',
          remoteName: widget.callerName,
          remotePicture: widget.callerPicture,
          isCaller: false,
          agoraToken: calleeToken,
        ),
      ),
    );
  }
```

**Step 2: Commit**

```bash
git add lib/features/call/presentation/screens/incoming_call_screen.dart
git commit -m "fix(call): pass server-issued Agora token to callee on call accept"
```

---

### Task 10: Add "Call Client" button in handyman_home_page.dart

**Files:**
- Modify: `lib/features/handyman/presentation/screens/handyman_home_page.dart`

The handyman needs a "Call Client" button in the booking details sheet for `confirmed` and `in_progress` bookings. The booking map contains `clientId` and `clientName`.

**Step 1: Add imports at the top of handyman_home_page.dart**

After the existing imports, add (if not already present):
```dart
import 'package:fixilya_app/features/call/presentation/screens/call_screen.dart';
import 'package:fixilya_app/services/call_service.dart';
```

**Step 2: Add `_callClient` method to `_HandymanHomePageState`**

Add this method anywhere in `_HandymanHomePageState` (e.g., near the bottom before `dispose()`):

```dart
  Future<void> _callClient(BuildContext context, Map<String, dynamic> booking) async {
    final clientId   = booking['clientId']   as String?;
    final clientName = booking['clientName'] as String? ?? 'Client';

    if (clientId == null || clientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client information not available')),
      );
      return;
    }

    // Close the detail sheet before showing the loading dialog
    Navigator.of(context).pop();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryColor),
      ),
    );

    try {
      final result = await CallService().initiateCall(
        calleeId:   clientId,
        calleeName: clientName,
        callerName: _handymanName,
      );

      if (!context.mounted) return;
      Navigator.of(context).pop(); // dismiss loading

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CallScreen(
            callId:      result['callId']!,
            remoteUid:   clientId,
            remoteName:  clientName,
            isCaller:    true,
            agoraToken:  result['token'],
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not start call. No active booking found.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
```

**Step 3: Add "Call Client" button in `_showBookingDetailsSheet`**

In `_showBookingDetailsSheet`, find the line that begins the review card section:
```dart
                    // ── Client review (visible once booking is completed) ──
                    if (status == 'completed' && booking['rating'] != null) ...[
```
(around line 1682)

Just before it, insert the "Call Client" button:

```dart
                    // ── Call client (only for active bookings) ────────────
                    if (status == 'confirmed' || status == 'in_progress') ...[
                      SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.phone, color: Colors.white),
                          label: const Text(
                            'Call Client',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () => _callClient(context, booking),
                        ),
                      ),
                    ],
```

**Step 4: Commit**

```bash
git add lib/features/handyman/presentation/screens/handyman_home_page.dart
git commit -m "feat(call): add Call Client button in handyman booking details sheet"
```

---

### Task 11: Wrap ClientHomePage with CallListener + update caller sites

**Files:**
- Modify: `lib/features/client/presentation/screens/client_home_page.dart`
- Modify: `lib/features/handyman/presentation/widgets/handyman_card.dart`
- Modify: `lib/features/client/presentation/screens/handymen_map_page.dart`

**Step 1: Add CallListener import to client_home_page.dart**

Add import at the top:
```dart
import 'package:fixilya_app/features/call/presentation/widgets/call_listener.dart';
```

**Step 2: Wrap build() return value with CallListener**

In `client_home_page.dart`, the `build()` method returns `Scaffold(...)`.
Wrap it:

```dart
  @override
  Widget build(BuildContext context) {
    return CallListener(
      child: Scaffold(
        backgroundColor: AppColors.backgroundColor(context),
        body: SafeArea(
          // ... rest unchanged ...
        ),
      ),
    );
  }
```

**Step 3: Update initiateCall params in handyman_card.dart**

In `handyman_card.dart` around line 72, the call to `initiateCall` uses old named params `handymanId:` and `handymanName:`. Update to new param names:

Replace:
```dart
      final result = await CallService().initiateCall(
        handymanId: handymanId,
        handymanName: handymanName,
        callerName: callerName,
      );
```

With:
```dart
      final result = await CallService().initiateCall(
        calleeId:   handymanId,
        calleeName: handymanName,
        callerName: callerName,
      );
```

**Step 4: Update initiateCall params in handymen_map_page.dart**

In `handymen_map_page.dart` around line 293, same rename:

Replace:
```dart
      final result = await CallService().initiateCall(
        handymanId: handymanId,
        handymanName: handymanName,
        callerName: callerName,
      );
```

With:
```dart
      final result = await CallService().initiateCall(
        calleeId:   handymanId,
        calleeName: handymanName,
        callerName: callerName,
      );
```

**Step 5: Commit**

```bash
git add lib/features/client/presentation/screens/client_home_page.dart
git add lib/features/handyman/presentation/widgets/handyman_card.dart
git add lib/features/client/presentation/screens/handymen_map_page.dart
git commit -m "feat(call): enable client to receive calls + rename initiateCall params"
```

---

## Testing Checklist

### Backend smoke test (manual, with curl)

```bash
# 1. Start call-service
cd fixilya-backend/fixilya-microservices/services/call-service && npm start

# 2. Health check
curl http://localhost:3007/health
# Expected: {"service":"call-service","status":"healthy",...}

# 3. Initiate call without auth (expect 401)
curl -X POST http://localhost:3007/api/calls/initiate \
  -H "Content-Type: application/json" \
  -d '{"calleeId":"test","callerName":"Test","calleeName":"Callee"}'
# Expected: {"success":false,"message":"No token provided"}

# 4. Initiate call with valid Firebase JWT but no booking (expect 403)
# (use a real JWT from Firebase console or the app)
curl -X POST http://localhost:3007/api/calls/initiate \
  -H "Authorization: Bearer <REAL_FIREBASE_JWT>" \
  -H "Content-Type: application/json" \
  -d '{"calleeId":"nonexistent-uid","callerName":"Test","calleeName":"Callee"}'
# Expected: {"success":false,"message":"No active booking found between caller and callee"}
```

### Flutter integration test

1. Create a booking between a client and handyman (confirm it from handyman side)
2. Log in as client → go to client home page → tap call button on handyman card
3. Expected: call-service creates call doc in Firestore, caller screen shows "Ringing..."
4. Log in as handyman on a second device → IncomingCallScreen appears
5. Handyman taps Accept → call-service returns callee token, both join Agora channel
6. Verify voice works, timer starts, mute/speaker buttons work
7. Either side ends call → status → "ended", both screens close
8. Log in as handyman → open confirmed booking → "Call Client" button visible
9. Tap Call Client → client device (with CallListener on ClientHomePage) shows IncomingCallScreen
