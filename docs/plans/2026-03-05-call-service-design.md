# Call Service Design — 2026-03-05

## Overview

Dedicated `call-service` (port 3007) for secure in-app voice calls between clients and handymen. Both parties can initiate calls. Maximum security: server-controlled call creation, booking-link authorization, and separate Agora tokens per identity.

---

## Architecture

```
Flutter app
  │
  ├─► POST /api/calls/initiate
  │     Body: { calleeId, calleeName, calleePicture? }
  │     Auth: Firebase JWT (caller identity)
  │     → validates shared booking exists (status: confirmed | in_progress)
  │     → generates callerToken + calleeToken via Agora SDK
  │     → writes /calls/{callId} to Firestore (server-side only)
  │     → returns { callId, callerToken }
  │
  └─► GET /api/calls/:callId/accept
        Auth: Firebase JWT (callee identity)
        → validates req.uid == call.calleeId
        → updates call status to 'active'
        → returns { calleeToken } (pre-generated, stored on call doc)

Firestore /calls/{callId}
  callId, callerId, calleeId,
  callerName, calleeName, callerPicture?, calleePicture?,
  status: ringing | active | rejected | ended | missed,
  channelName (= callId),
  calleeToken (pre-generated, server-only write),
  createdAt, updatedAt
```

Both sides stream the Firestore doc for real-time status updates (existing pattern — no change).

---

## Security Model

1. **Booking authorization**: `/initiate` checks Firestore `bookings` for a doc where `(clientId==callerId AND handymanId==calleeId) OR (handymanId==callerId AND clientId==calleeId)` with `status IN [confirmed, in_progress]`. Fails with 403 otherwise.

2. **Token separation**: Caller token returned from `/initiate`, NOT stored in Firestore. Callee token stored on the call doc, returned only from `/accept` to the verified callee.

3. **Callee identity check**: `/accept` verifies `req.uid == call.calleeId`. Anyone else gets 403.

4. **Server-side call creation**: Flutter no longer writes to `/calls` directly for call creation. Only status updates (`rejected`, `ended`, `missed`) are written client-side.

5. **Rate limiting**: `/initiate` → 10 req/min per user (nginx `call_limit` zone). `/accept` → standard 20 req/min.

6. **Token TTL**: 3600s (1 hour), clamped to 60s–86400s.

---

## Flutter Changes

| File | Change |
|------|--------|
| `app_config.dart` | Add `callServiceUrl` (default `http://10.0.2.2:3007/api`) |
| `call_service.dart` | `initiateCall()` → POST to call-service; new `acceptCall()` → GET callee token then update Firestore status |
| `incoming_call_screen.dart` | `_accept()` calls `callService.acceptCall()` to get callee token before navigating to `CallScreen` |
| `handyman_home_page.dart` | Add "Call Client" button in booking details sheet for confirmed/in_progress bookings |
| `client_home_page.dart` or root widget | Wrap with `CallListener` so clients can receive calls from handymen |

---

## Backend: New `call-service`

**Location:** `fixilya-backend/fixilya-microservices/services/call-service/`

**Structure:**
```
call-service/
  package.json
  src/
    app.js
    routes/call.routes.js
    controllers/call.controller.js
    services/call.service.js
    utils/agoraToken.js   (copy from auth-service)
```

**Port:** 3007

**Endpoints:**
- `POST /api/calls/initiate` — create call, return caller token
- `GET /api/calls/:callId/accept` — verify callee, return callee token
- `GET /health`

---

## Nginx

Add upstream `call_service` → `call-service:3007` and location `/api/calls` with rate limit zone `call_limit` (10r/m).

---

## Call Flow

```
Client                    Server                    Handyman
  │                          │                          │
  ├─ POST /calls/initiate ──►│                          │
  │◄── { callId, token } ───┤ writes /calls/{id}       │
  │                          │                          │
  │  joins Agora channel     │     Firestore snapshot ─►│
  │                          │                          ├─ IncomingCallScreen
  │                          │                          │
  │                          │◄─ GET /calls/{id}/accept─┤
  │                          ├──── { calleeToken } ────►│
  │                          │  status → active         │
  │                          │                          ├─ joins Agora channel
  │◄══════════ Agora RTC voice call ══════════════════►│
  │                          │                          │
  ├─ endCall() ──────────────────────────────────────►  │
  │   (Firestore write: status=ended)                   │
```
