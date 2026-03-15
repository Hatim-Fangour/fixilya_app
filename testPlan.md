# Fixilya — Manual Test Plan

**App:** Fixilya – Handyman Services Marketplace
**Platforms:** Android (primary), iOS
**Test date:** ___________
**Tester:** ___________
**Backend:** `https://api.fixilya.pro` (prod) or `localhost` (local)

---

## How to use this plan

- Work through each section top-to-bottom.
- Mark each row **PASS**, **FAIL**, or **SKIP** (with a reason) in the **Actual Result** column.
- For failures note the exact screen, steps to reproduce, and what you observed.
- Reset app state between unrelated sections by logging out.
- Tests marked ⚠️ were found as bugs or gaps during automated testing — pay extra attention.

---

## Results Summary

| Section | Total | Pass | Fail | Skip |
|---|---|---|---|---|
| 1. Authentication | 20 | | | |
| 2. Handyman | 30 | | | |
| 3. Client | 27 | | | |
| 4. Booking | 34 | | | |
| 5. Calls | 20 | | | |
| 6. Notification | 22 | | | |
| 7. Admin | 12 | | | |
| 8. Chat | 5 | | | |
| 9. Offline / Edge Cases | 7 | | | |
| 10. Security | 9 | | | |
| **Total** | **186** | | | |

---

## 1. Authentication

### 1.1 Guest access

| # | Action | Expected Result | Actual Result |
|---|---|---|---|
| 1.1 | Open app without being logged in | Splash / welcome screen shown, then guest home | |
| 1.2 | Browse handymen as guest | List loads, no crash | |
| 1.3 | Tap "Book" on any handyman as guest | Redirected to login screen | |

### 1.2 Client registration

| # | Action | Expected Result | Actual Result |
|---|---|---|---|
| 1.4 | Tap Sign Up → choose "Client" | Registration form opens | |
| 1.5 | Submit with all fields empty | Validation errors shown inline, no API call | |
| 1.6 | Submit with invalid email format (e.g. `abc@`) | Email validation error shown | |
| 1.7 | Submit with valid name, email, password | Account created, email verification screen shown | |
| 1.8 | Open inbox, tap verification link | Email marked as verified in Firebase | |
| 1.9 | Return to app, complete profile setup (name, city) | Profile setup screen shown, fields save correctly | |
| 1.10 | Skip profile setup | Home screen loads without crash | |
| 1.11 | Try to register again with the same email | Error: "email already in use" shown | |

### 1.3 Handyman registration

| # | Action | Expected Result | Actual Result |
|---|---|---|---|
| 1.12 | Sign Up → choose "Handyman" | Handyman registration form opens | |
| 1.13 | Submit valid data | Account created, handyman profile setup shown | |
| 1.14 | Complete profile setup (skills, city, hourly rate) | Profile saved, handyman home loads | |

### 1.4 Login & session

| # | Action | Expected Result | Actual Result |
|---|---|---|---|
| 1.15 | Login with correct client credentials | Client home screen loads | |
| 1.16 | Login with correct handyman credentials | Handyman home screen loads | |
| 1.17 | Login with wrong password | Error snackbar shown, no crash | |
| 1.18 | Login with unknown email | Error snackbar shown | |
| 1.19 | Logout from Settings | Returns to welcome/login screen, token cleared | |
| 1.20 | Force-close app and reopen while logged in | User stays logged in, correct home screen shown | |

---

## 2. Handyman

### 2.1 Profile & public listing

| # | Action | Expected Result | Actual Result |
|---|---|---|---|
| 2.1 | As client: open handymen list | List loads — name, rating, city, skills visible per card, no null crash | |
| 2.2 | Pull to refresh on handymen list | List reloads without crash | |
| 2.3 | Tap a handyman card | Handyman details page opens | |
| 2.4 | Check details page content | Name, bio, skills, city, hourly rate, rating, review count all displayed | |
| 2.5 | As client: open map view | Map renders with handyman pins at correct locations | |
| 2.6 | Tap a pin on the map | Handyman info sheet or details page opens | |
| 2.7 | Open `GET /users/handyman/nearby?lat=33.57&lon=-7.59` (Casablanca) | Returns handymen sorted by distance ⚠️ param is `lon` not `lng` | |

### 2.2 Handyman own profile

| # | Action | Expected Result | Actual Result |
|---|---|---|---|
| 2.8 | Login as handyman → open Profile tab | Name, email, phone, city, bio, skills, hourly rate shown | |
| 2.9 | Edit bio and save | Bio updates immediately on profile | |
| 2.10 | Edit skills list and save | Skills updated, visible to clients | |
| 2.11 | Edit hourly rate and save | New rate shown on public profile | |
| 2.12 | Change profile picture | New image uploaded via Cloudinary, avatar in app bar updates | |

### 2.3 Availability

| # | Action | Expected Result | Actual Result |
|---|---|---|---|
| 2.13 | Open availability settings | Current availability toggle state shown | |
| 2.14 | Toggle availability to ON | `isAvailable: true` saved; handyman appears in search results | |
| 2.15 | Toggle availability to OFF | `isAvailable: false` saved; clients cannot book this handyman ⚠️ booking returns 400 "Provider is not currently available" | |
| 2.16 | Force-close app, reopen, check availability toggle | State persisted from last save | |

### 2.4 Stats & ratings

| # | Action | Expected Result | Actual Result |
|---|---|---|---|
| 2.17 | Open handyman stats page | Total bookings, completed, rating shown | |
| 2.18 | After client submits a review — recheck stats | Rating average and review count updated | |
| 2.19 | Open rating-stats breakdown | Star distribution (1★–5★ counts) shown | |

### 2.5 Privacy settings

| # | Action | Expected Result | Actual Result |
|---|---|---|---|
| 2.20 | Open Settings → Privacy section | "Show Phone Number" toggle visible, OFF by default | |
| 2.21 | Enable "Show Phone Number" | Toggle ON; subtitle changes to indicate phone is visible | |
| 2.22 | As any client: open this handyman's details | Real phone number shown in contact card | |
| 2.23 | Disable "Show Phone Number" | Toggle OFF; phone hidden again for all clients | |
| 2.24 | Restart app, open Settings | Toggle state persisted (matches last saved value) | |
| 2.25 | Change location privacy to "City Only" | Map shows handyman at city center, not exact address | |
| 2.26 | Change location privacy to "Exact Location" | Map shows precise pin | |

### 2.6 Notification preferences

| # | Action | Expected Result | Actual Result |
|---|---|---|---|
| 2.27 | Open Settings → Notifications | Push Notifications toggle visible | |
| 2.28 | Disable Push Notifications | Toggle OFF saved, setting persists on reload | |
| 2.29 | Re-enable Push Notifications | Toggle ON saved | |

### 2.7 Account actions

| # | Action | Expected Result | Actual Result |
|---|---|---|---|
| 2.30 | Change password from Settings | Success message; old password no longer works for login | |

---

## 3. Client

### 3.1 Home & discovery

| # | Action | Expected Result | Actual Result |
|---|---|---|---|
| 3.1 | Open client home | Handymen list and/or map visible | |
| 3.2 | Pull to refresh | List reloads without crash | |
| 3.3 | Switch between list and map view | Both views load correctly | |

### 3.2 Handyman details (client view)

| # | Action | Expected Result | Actual Result |
|---|---|---|---|
| 3.4 | Tap a handyman card | Details page opens | |
| 3.5 | Phone card when handyman has phone hidden | Shows "Hidden by handyman" with lock icon | |
| 3.6 | Tap call button when phone is hidden | Snackbar: "has not shared their phone number yet" | |
| 3.7 | Phone card when handyman has phone visible | Real phone number shown | |
| 3.8 | Tap phone card when number visible | Device dialer opens with correct number | |

### 3.3 Favorites

| # | Action | Expected Result | Actual Result |
|---|---|---|---|
| 3.9 | Tap heart icon on a handyman | Icon turns red, snackbar "Added to favorites" | |
| 3.10 | Tap heart icon again (remove) | Icon turns outline, snackbar "Removed from favorites" | |
| 3.11 | Navigate to Favorites page | Favorited handyman appears in list | |
| 3.12 | Check Client Profile favorites count | Count matches actual number of favorited handymen | |
| 3.13 | Re-open handyman details after favoriting | Heart icon still red (state persisted) | |
| 3.14 | Navigate to Favorites page with no favorites | Empty state shown | |
| 3.15 | Tap a favorite card | Handyman details page opens | |
| 3.16 | Tap red heart (remove) in favorites list | Confirmation dialog appears | |
| 3.17 | Confirm removal | Handyman removed from list, count updates | |

### 3.4 Client profile

| # | Action | Expected Result | Actual Result |
|---|---|---|---|
| 3.18 | Open client profile page | Name, email, city, profile picture shown | |
| 3.19 | Check "Total Bookings" stat | Matches actual booking count | |
| 3.20 | Check "Favorites" stat | Matches favorited handymen count | |
| 3.21 | Edit name | Change saved, profile reloads with new name | |
| 3.22 | Edit city | Change saved | |
| 3.23 | Edit phone number | Change saved | |
| 3.24 | Change profile picture | Image uploaded, displayed correctly | |

### 3.5 Client stats

| # | Action | Expected Result | Actual Result |
|---|---|---|---|
| 3.25 | Open client stats (profile page) | Bookings count, favorites count shown | |
| 3.26 | Create a booking and recheck stats | Bookings count increments | |
| 3.27 | Change password from Settings | Success message; old password no longer works | |

---

## 4. Booking

> **Setup:** Use two devices or two accounts — one client, one handyman. The handyman must have `isAvailable: true`.

### 4.1 Booking creation (client)

| # | Action | Expected Result | Actual Result |
|---|---|---|---|
| 4.1 | Tap "Book Now" on a handyman — submit with all fields empty | Validation errors shown, no API call | |
| 4.2 | Submit with a past date/time as `scheduledAt` | Error: "cannot schedule in the past" | |
| 4.3 | Try to book a handyman with availability OFF | Error: "Provider is not currently available" ⚠️ confirmed bug in automated test | |
| 4.4 | Submit a valid booking (service, description, address, city, date) | 201 — booking created, appears in client's bookings list with status **pending** | |
| 4.5 | Check handyman's booking list | New booking visible with **pending** badge | |
| 4.6 | Check client's booking list | New booking visible with **pending** badge | |
| 4.7 | Handyman receives push notification | "New Booking Request" notification delivered | |

### 4.2 Accept flow (pending → confirmed)

| # | Action | Expected Result | Actual Result |
|---|---|---|---|
| 4.8 | Client tries to accept their own booking | Error / button not available to client — only handyman can accept ⚠️ API returns 403 | |
| 4.9 | Handyman taps Accept on the booking | Status changes to **confirmed**; client notified | |
| 4.10 | Handyman tries to accept the same booking again | Error shown — cannot transition from confirmed → confirmed ⚠️ API returns 400 | |

### 4.3 Start flow (confirmed → in_progress)

| # | Action | Expected Result | Actual Result |
|---|---|---|---|
| 4.11 | Client tries to start the job | Error / button not available — only handyman can start ⚠️ API returns 403 | |
| 4.12 | Handyman taps "Start Job" | Status changes to **in_progress**; client can see update | |

### 4.4 Complete flow (in_progress → completed)

| # | Action | Expected Result | Actual Result |
|---|---|---|---|
| 4.13 | Handyman tries to mark job complete | Error — only client can mark completed ⚠️ API returns 403 | |
| 4.14 | Client taps "Mark Complete" | Status changes to **completed** | |
| 4.15 | Try to cancel after completion | Error — completed is a terminal state ⚠️ API returns 400 | |

### 4.5 Review (client, after completion)

| # | Action | Expected Result | Actual Result |
|---|---|---|---|
| 4.16 | Client submits a review with rating 1–5 and comment | Review saved, handyman stats updated | |
| 4.17 | Client tries to submit a second review on same booking | Error: "Review already submitted" ⚠️ API returns 409 | |
| 4.18 | Submit review with rating 0 or 6 | Validation error shown ⚠️ API returns 400 | |
| 4.19 | Handyman tries to submit a review | Error — only the client can review ⚠️ API returns 403 | |

### 4.6 Decline flow

| # | Action | Expected Result | Actual Result |
|---|---|---|---|
| 4.20 | Handyman taps Decline on a pending booking | Status changes to **declined**; client notified | |
| 4.21 | Handyman tries to accept the declined booking | Error — declined is terminal ⚠️ API returns 400 | |

### 4.7 Cancel flow

| # | Action | Expected Result | Actual Result |
|---|---|---|---|
| 4.22 | Client cancels a pending booking | Status changes to **cancelled** | |
| 4.23 | Handyman cancels a pending booking | Status changes to **cancelled** | |
| 4.24 | Try to cancel an already-cancelled booking | Error — cancelled is terminal ⚠️ API returns 400 | |

### 4.8 Access control

| # | Action | Expected Result | Actual Result |
|---|---|---|---|
| 4.25 | Open booking details as the client who created it | 200 — booking details shown | |
| 4.26 | Open booking details as the assigned handyman | 200 — booking details shown | |
| 4.27 | Open booking details as a third user (not involved) | Access denied — booking not visible ⚠️ API returns 403 | |
| 4.28 | Open a booking ID that does not exist | Error screen or 404 message ⚠️ API returns 404 | |

### 4.9 Filters & list

| # | Action | Expected Result | Actual Result |
|---|---|---|---|
| 4.29 | Filter client bookings by status "completed" | Only completed bookings shown ⚠️ requires Firestore index — may fail if index missing | |
| 4.30 | Filter client bookings by status "pending" | Only pending bookings shown | |
| 4.31 | Filter handyman bookings by status | Correct subset returned | |
| 4.32 | Paginate booking list (scroll to load more) | Next page loads without duplicates | |

### 4.10 Real-time updates (SSE)

| # | Action | Expected Result | Actual Result |
|---|---|---|---|
| 4.33 | Client is on booking list screen while handyman accepts | Booking status updates in real-time without refresh | |
| 4.34 | Handyman is on booking requests screen when client creates booking | New booking appears in real-time | |

---

## 5. Calls

> **Setup:** Client and handyman must have a booking in **confirmed** or **in_progress** status.

### 5.1 Client calls Handyman

| # | Action | Expected Result | Actual Result |
|---|---|---|---|
| 5.1 | Client opens handyman details — no confirmed booking | "Call" button absent or disabled ⚠️ backend returns 403 if forced | |
| 5.2 | Client opens handyman details — confirmed booking exists | "Call" button visible and active | |
| 5.3 | Client taps "Call" | Agora token generated server-side; incoming call screen appears on handyman device | |
| 5.4 | Verify: no Agora token written in Firestore call doc | `calls/{id}` doc has `status: ringing`, no token field | |
| 5.5 | Handyman accepts the call | Both sides join Agora RTC voice channel; call screen shown on both devices | |
| 5.6 | Both parties speak | Audio works in both directions | |
| 5.7 | Client ends the call | Call ends for both; status updated to "ended" | |

### 5.2 Handyman calls Client

| # | Action | Expected Result | Actual Result |
|---|---|---|---|
| 5.8 | Handyman opens confirmed booking detail | "Call Client" button visible | |
| 5.9 | Handyman taps "Call Client" | Incoming call screen on client device | |
| 5.10 | Client accepts | Voice call established | |
| 5.11 | Handyman ends call | Call ends cleanly for both | |

### 5.3 Reject & miss

| # | Action | Expected Result | Actual Result |
|---|---|---|---|
| 5.12 | Handyman rejects incoming call | Client sees "Call rejected" feedback | |
| 5.13 | Handyman does not answer | Call status becomes **missed** after timeout | |

### 5.4 Edge cases

| # | Action | Expected Result | Actual Result |
|---|---|---|---|
| 5.14 | Caller tries to accept their own outgoing call | Error: Forbidden ⚠️ API returns 403 | |
| 5.15 | Callee taps Accept twice rapidly | Second tap fails gracefully — "Call is already active" ⚠️ API returns 409 | |
| 5.16 | Try to call using a fake / non-existent callId | Error: Call not found ⚠️ API returns 404 | |
| 5.17 | Try to initiate 11 calls in under 1 minute (rate limit) | 11th request blocked ⚠️ API returns 429 Too Many Requests | |
| 5.18 | App goes to background during active call | Audio continues uninterrupted | |

### 5.5 Agora token

| # | Action | Expected Result | Actual Result |
|---|---|---|---|
| 5.19 | Initiate a call and check token prefix | Agora token starts with `007` | |
| 5.20 | Initiate the same call twice within cache TTL | Same token returned on both requests (server cache working) | |

---

## 6. Notification

### 6.1 Push delivery

| # | Action | Expected Result | Actual Result |
|---|---|---|---|
| 6.1 | Client creates a booking | Handyman receives push notification "New Booking Request" | |
| 6.2 | Handyman accepts a booking | Client receives push notification "Booking Confirmed" | |
| 6.3 | Handyman declines a booking | Client receives "Booking Declined" push notification | |
| 6.4 | Job marked in_progress | Client receives status update notification | |
| 6.5 | Job marked completed | Client receives "Job Completed" + review prompt notification | |
| 6.6 | Booking cancelled | Relevant party receives cancellation notification | |
| 6.7 | Incoming call | Callee receives push with caller name; tapping opens incoming call screen | |

### 6.2 Notification list (in-app)

| # | Action | Expected Result | Actual Result |
|---|---|---|---|
| 6.8 | Open Notifications page | All past notifications listed, newest first | |
| 6.9 | Unread notifications | Visually distinguished (bold / highlight) from read ones | |
| 6.10 | Filter by unread only | Only unread notifications shown ⚠️ requires Firestore index — verify it works | |
| 6.11 | Check unread badge/count in nav bar | Count matches actual unread notifications | |
| 6.12 | Tap a booking notification | Navigates to the correct booking detail screen | |
| 6.13 | Tap a call notification | Navigates to the call / incoming call screen | |

### 6.3 Mark as read

| # | Action | Expected Result | Actual Result |
|---|---|---|---|
| 6.14 | Tap a single notification | Marked as read; unread count decreases by 1 | |
| 6.15 | Tap "Mark all as read" | All notifications marked read; unread count becomes 0 | |
| 6.16 | Reopen Notifications page after marking all read | No unread indicators visible | |
| 6.17 | Check unread count in nav bar after mark-all-read | Badge shows 0 or disappears | |

### 6.4 FCM token management

| # | Action | Expected Result | Actual Result |
|---|---|---|---|
| 6.18 | Login on a new device | FCM token registered; push notifications start arriving on new device | |
| 6.19 | Logout | FCM token removed; push notifications stop on that device | |
| 6.20 | Login on a second device simultaneously | Both devices receive push notifications | |

### 6.5 Seeded notifications (UI check)

> Use the 16 fake notifications seeded into UID `MsITXctPvRgic4xJoKXpwwAzDo93`

| # | Action | Expected Result | Actual Result |
|---|---|---|---|
| 6.21 | Open notifications page on seeded account | 16 notifications shown, 8 unread | |
| 6.22 | Check notification types are visually distinct | Booking, call, system, review types each have correct icon/label | |

---

## 7. Admin

> **Setup:** Login with an account that has `userType: admin` and custom claim `role: admin`.

### 7.1 Admin access & routing

| # | Action | Expected Result | Actual Result |
|---|---|---|---|
| 7.1 | Login with admin account | Admin home shown — not the client/handyman home | |
| 7.2 | Open User Management | List of users (clients + handymen) loads | |
| 7.3 | Open Analytics page | Charts/stats load without crash | |

### 7.2 Booking visibility

| # | Action | Expected Result | Actual Result |
|---|---|---|---|
| 7.4 | Admin opens a specific booking by ID | Booking details visible regardless of who created it ⚠️ confirmed working in API test | |
| 7.5 | Admin views booking list | Returns 200 — note: currently shows only bookings where admin is the provider (design gap ⚠️) | |

### 7.3 User management

| # | Action | Expected Result | Actual Result |
|---|---|---|---|
| 7.6 | Suspend a handyman from admin panel | Handyman's `suspended: true` in Firestore; they cannot access app features | |
| 7.7 | Suspended handyman tries to use the app | Access blocked or limited — appropriate error shown | |
| 7.8 | Approve a pending handyman | Handyman `approved: true` in Firestore; status badge updates | |

### 7.4 Dispute & Resolve ⚠️ (routes missing — expected to fail until fixed)

| # | Action | Expected Result | Actual Result |
|---|---|---|---|
| 7.9 | Client opens a dispute on an in_progress booking | Status changes to **disputed** ⚠️ `PUT /bookings/:id/dispute` route not registered — expect 404 until fixed | |
| 7.10 | Non-admin tries to resolve a dispute | Error: "Only admin can resolve" ⚠️ 403 expected, currently 404 | |
| 7.11 | Admin resolves the dispute | Status changes to **resolved** ⚠️ `PUT /bookings/:id/resolve` route not registered — expect 404 until fixed | |
| 7.12 | After resolve: booking is in terminal state | Cannot transition from resolved to any other state | |

---

## 8. Chat

| # | Action | Expected Result | Actual Result |
|---|---|---|---|
| 8.1 | Client opens chat with a handyman | Chat room loads with message history (or empty state) | |
| 8.2 | Client sends a text message | Message appears on sender side instantly | |
| 8.3 | Handyman receives the message in real-time | Message appears without refresh on handyman side | |
| 8.4 | Handyman replies | Reply appears on both sides | |
| 8.5 | Navigate away and back to chat | Full message history still visible | |

---

## 9. Offline / Edge Cases

| # | Action | Expected Result | Actual Result |
|---|---|---|---|
| 9.1 | Disable internet, open app | Cached data shown (profile, bookings, favorites) — Firestore offline persistence active | |
| 9.2 | Re-enable internet while on a cached screen | Data refreshes automatically | |
| 9.3 | Switch between light and dark mode | All screens render correctly in both modes | |
| 9.4 | Switch language to Arabic (AR) | App text changes to Arabic, RTL layout correct, no overflow | |
| 9.5 | Switch language to French (FR) | App text changes to French, no missing strings | |
| 9.6 | Open app on a device with slow/throttled network | Loading indicators shown; no silent failures | |
| 9.7 | Handyman leaves `isAvailable` OFF and client tries to book | Client sees clear error — not a silent 400 ⚠️ verify error message surfaces in UI | |

---

## 10. Security Spot-checks

| # | Action | Expected Result | Actual Result |
|---|---|---|---|
| 10.1 | Make any API request with no auth token | 401 Unauthorized — no data leaked | |
| 10.2 | Inspect Firestore `calls/{id}` doc during an active call | No Agora tokens stored in Firestore — tokens only transmitted in API response | |
| 10.3 | Try to access another user's booking directly (client B opens booking of client A) | 403 Access denied ⚠️ confirmed working in API test | |
| 10.4 | Caller tries to accept their own outgoing call via API | 403 Forbidden ⚠️ confirmed working | |
| 10.5 | Try to initiate a call with no active booking | 403 "No active booking found between caller and callee" ⚠️ confirmed working | |
| 10.6 | Check Firestore `clients/{uid}` doc — favorites field name | Favorites stored in `favoriteHandymen` field (not `favorites`) | |
| 10.7 | Check Firestore `handymen/{uid}` doc after disabling phone reveal | `showPhoneNumber: false` persisted | |
| 10.8 | Submit review with rating 6 (above max) | Rejected with validation error — not stored ⚠️ confirmed working in API test | |
| 10.9 | Handyman tries to submit a review on a booking they worked | 403 — only the client can review ⚠️ confirmed working | |

---

## Notes / Bugs Found

_Use this space to record failures with screen name, steps to reproduce, and observed vs expected behaviour._

```
Bug #:
Screen:
Steps:
Expected:
Actual:
```

---

## Known Issues (from automated API testing — verify manually)

| # | Issue | Severity | Status |
|---|---|---|---|
| A | `auth.controller.js` — `auth` import was commented out; `GET /auth/validate` returned 401 | High | Fixed in code — requires service restart |
| B | `notification-service` — `dotenv` loaded without explicit path | High | Fixed in code |
| C | Booking & notification services started with stale Firebase project credentials | High | Fix: restart services |
| D | `GET /bookings` list — Firestore index `clientUid+createdAt` needed | Medium | Create index in Firebase Console |
| E | `GET /bookings?status=X` — Firestore index `clientUid+status+createdAt` needed | Medium | Create index in Firebase Console |
| F | `GET /notifications?unreadOnly=true` — Firestore index `read+userId+createdAt` needed | Medium | Index built automatically — verify it works |
| G | `PUT /bookings/:id/dispute` and `/resolve` — routes not registered in `booking.routes.js` | High | Add routes and controller methods |
| H | Review endpoint returns HTTP 201 instead of 200 | Low | Minor — update controller to return 200 |
| I | `PUT /notifications/:id/read` with bad ID returns 500 instead of 404 | Low | Add error mapping in notification controller |
| J | Favorites endpoint adds non-existent handyman IDs without validation | Low | Add Firestore existence check before insert |
| K | Admin has no `GET /bookings/all` endpoint — sees only own bookings | Low | Add admin-only global list endpoint |
