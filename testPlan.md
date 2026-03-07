# Fixilya Manual Test Plan

**App:** Fixilya – Handyman Services Marketplace
**Platforms:** Android (primary), iOS
**Test date:** ___________
**Tester:** ___________

---

## How to use this plan

- Work through each section top-to-bottom.
- Mark each step: **PASS**, **FAIL**, or **SKIP** (with a reason).
- For failures, note the exact screen and what you observed.
- Reset app state between unrelated sections by logging out.

---

## 1. Authentication

### 1.1 Guest access
| # | Action | Expected result | Result |
|---|--------|-----------------|--------|
| 1 | Open app without being logged in | Welcome / splash screen is shown, then guest home | |
| 2 | Browse handymen as guest | List loads without crash | |
| 3 | Tap "Book" on any handyman as guest | App redirects to login screen | |

### 1.2 Client registration
| # | Action | Expected result | Result |
|---|--------|-----------------|--------|
| 4 | Tap Sign Up → choose "Client" | Registration form opens | |
| 5 | Submit with empty fields | Validation errors shown, no API call | |
| 6 | Submit with invalid email format | Email validation error shown | |
| 7 | Submit with valid data | Account created, email verification screen shown | |
| 8 | Check inbox, tap verification link | Email marked as verified | |
| 9 | Return to app, complete profile setup | Profile setup screen shown with city/name fields | |
| 10 | Skip profile setup (if allowed) | Home screen loads without crash | |
| 11 | Try to register with the same email again | Error: "email already in use" | |

### 1.3 Handyman registration
| # | Action | Expected result | Result |
|---|--------|-----------------|--------|
| 12 | Sign Up → choose "Handyman" | Handyman registration form opens | |
| 13 | Submit valid data | Account created, handyman profile setup screen shown | |
| 14 | Complete profile setup (skills, city, rate) | Profile saved, handyman home loads | |

### 1.4 Login
| # | Action | Expected result | Result |
|---|--------|-----------------|--------|
| 15 | Login with correct client credentials | Client home screen loads | |
| 16 | Login with correct handyman credentials | Handyman home screen loads | |
| 17 | Login with wrong password | Error snackbar shown, no crash | |
| 18 | Login with unknown email | Error snackbar shown | |
| 19 | Logout (from Settings) | Returns to welcome/login screen, tokens cleared | |
| 20 | Re-login | Same account data restored | |

---

## 2. Client Home

### 2.1 Home screen loads
| # | Action | Expected result | Result |
|---|--------|-----------------|--------|
| 21 | Open client home | Handymen list and/or map visible | |
| 22 | Pull to refresh | List reloads without crash | |
| 23 | Switch between list and map view (if toggled) | Both views load correctly | |

### 2.2 Handyman card
| # | Action | Expected result | Result |
|---|--------|-----------------|--------|
| 24 | Tap a handyman card | Handyman details page opens | |
| 25 | Check name, rating, city, skills shown | All fields displayed without null/crash | |

---

## 3. Handyman Details Page

### 3.1 Phone number privacy
| # | Action | Expected result | Result |
|---|--------|-----------------|--------|
| 26 | Open any handyman's details page | Phone card shows "Hidden by handyman" with lock icon (default state) | |
| 27 | Tap the bottom phone call button when phone is hidden | Snackbar: "has not shared their phone number yet" | |
| 28 | Handyman enables "Show Phone Number" in their settings (see section 8.1) | Phone number becomes visible in the details card | |
| 29 | Open the same handyman's details page as client | Real phone number shown in contact card | |
| 30 | Tap phone card when number is visible | Device dialer opens with correct number | |
| 31 | Tap bottom call button when number is visible | Device dialer opens | |

### 3.2 Favorites
| # | Action | Expected result | Result |
|---|--------|-----------------|--------|
| 32 | Tap the heart icon (favorite) on a handyman | Icon turns red, snackbar "Added to favorites" | |
| 33 | Tap heart icon again | Icon turns outline, snackbar "Removed from favorites" | |
| 34 | Navigate to Favorites page | Favorited handyman appears in list | |
| 35 | Navigate to Client Profile page | Favorites count matches actual favorites | |
| 36 | Re-open handyman details after favoriting | Heart icon still red (state persisted) | |

### 3.3 Booking
| # | Action | Expected result | Result |
|---|--------|-----------------|--------|
| 37 | Tap "Book Now" on a handyman | Booking dialog / form opens | |
| 38 | Submit booking with missing fields | Validation error shown | |
| 39 | Submit valid booking | Confirmation shown, booking appears in client bookings | |

---

## 4. Favorites Page

| # | Action | Expected result | Result |
|---|--------|-----------------|--------|
| 40 | Navigate to Favorites page (from client home nav) | Page loads without crash | |
| 41 | If no favorites yet | Empty state illustration shown | |
| 42 | If favorites exist | Handyman name, category, rating, city all visible (no null crash) | |
| 43 | Tap a favorite handyman card | Handyman details page opens | |
| 44 | Tap the red heart (remove) in the card | Confirmation dialog appears | |
| 45 | Confirm removal | Handyman removed from list, count updates | |
| 46 | Navigate to Favorites from Client Profile page | Same favorites shown | |

---

## 5. Client Bookings

| # | Action | Expected result | Result |
|---|--------|-----------------|--------|
| 47 | Navigate to "My Bookings" | List of bookings loads | |
| 48 | Check booking statuses shown (pending, confirmed, etc.) | Correct badges/labels | |
| 49 | Tap a booking | Booking detail view opens | |
| 50 | Cancel a pending booking | Status changes to "cancelled" | |

---

## 6. Client Profile

| # | Action | Expected result | Result |
|---|--------|-----------------|--------|
| 51 | Open client profile page | Name, email, city, profile picture shown | |
| 52 | Check "Total Bookings" stat | Matches actual count of bookings | |
| 53 | Check "Favorites" stat | Matches count of favorited handymen | |
| 54 | Edit profile (name / city / phone) | Changes saved, profile reloads with new data | |
| 55 | Change profile picture | New image uploaded and displayed | |

---

## 7. Handyman Map Page

| # | Action | Expected result | Result |
|---|--------|-----------------|--------|
| 56 | Open map view as client | Map renders with handyman pins | |
| 57 | Tap a pin | Handyman info sheet or details page opens | |
| 58 | Pins reflect handyman location privacy setting (city-level vs exact) | Pins are not all in the exact same spot | |

---

## 8. Handyman Settings

### 8.1 Phone privacy toggle
| # | Action | Expected result | Result |
|---|--------|-----------------|--------|
| 59 | Login as handyman, open Settings | "Privacy" section visible with "Show Phone Number" toggle | |
| 60 | Toggle is OFF by default | Correct initial state | |
| 61 | Enable "Show Phone Number" | Toggle turns ON, subtitle updates to "Clients with confirmed bookings can see your phone" | |
| 62 | As the client who has a confirmed booking with this handyman, check the handyman details page | Phone number now visible | |
| 63 | As the same client, check notifications | In-app notification: "[Handyman name] has shared their phone number" | |
| 64 | As a client with NO booking with this handyman, open their details | Phone number visible (phone is revealed for everyone once toggled) | |
| 65 | Disable "Show Phone Number" | Toggle turns OFF, phone hidden again | |
| 66 | Restart the handyman app and open Settings | Toggle state persisted (matches last saved value) | |

### 8.2 Notification preferences
| # | Action | Expected result | Result |
|---|--------|-----------------|--------|
| 67 | Disable "Push Notifications" | Toggle saved, setting persists on reload | |
| 68 | Re-enable "Push Notifications" | Toggle saved | |

### 8.3 Location privacy
| # | Action | Expected result | Result |
|---|--------|-----------------|--------|
| 69 | Change location privacy to "City Only" | Map shows handyman at city center, not exact address | |
| 70 | Change to "Exact Location" | Map shows precise pin | |

### 8.4 Account
| # | Action | Expected result | Result |
|---|--------|-----------------|--------|
| 71 | Change profile picture | Image uploaded, appbar avatar updates | |
| 72 | Change password | Success message; old password no longer works | |
| 73 | Logout | Returns to login screen | |

---

## 9. Booking Lifecycle (Handyman side)

| # | Action | Expected result | Result |
|---|--------|-----------------|--------|
| 74 | Client creates a booking | Handyman receives push notification | |
| 75 | Handyman opens Bookings tab | New pending booking appears | |
| 76 | Handyman accepts booking | Status changes to "confirmed"; client receives notification | |
| 77 | Handyman marks job as in_progress | Status updates; client can see it | |
| 78 | Handyman marks job as completed | Status "completed"; client can review | |
| 79 | Handyman declines a booking | Status "declined"; client notified | |

---

## 10. In-App Calling

### 10.1 Client calls Handyman
| # | Action | Expected result | Result |
|---|--------|-----------------|--------|
| 80 | Client opens handyman details for a handyman with a confirmed booking | "Call" option is available | |
| 81 | Client initiates a call | Incoming call screen appears on handyman device | |
| 82 | Handyman accepts | Both sides join Agora RTC voice channel; call screen shown | |
| 83 | Both parties can hear each other | Audio works in both directions | |
| 84 | Client ends the call | Call ends for both; status updated to "ended" | |
| 85 | Call is rejected by handyman | Client sees "Call rejected" feedback | |
| 86 | Handyman does not answer | Call status becomes "missed" after timeout | |

### 10.2 Handyman calls Client
| # | Action | Expected result | Result |
|---|--------|-----------------|--------|
| 87 | Handyman opens a confirmed booking detail sheet | "Call Client" button visible | |
| 88 | Handyman taps "Call Client" | Incoming call screen on client device | |
| 89 | Client accepts | Voice call established | |
| 90 | Handyman ends call | Call ends cleanly for both | |

### 10.3 Call edge cases
| # | Action | Expected result | Result |
|---|--------|-----------------|--------|
| 91 | Try to call a user with no shared confirmed booking | Call blocked (403 from backend) | |
| 92 | Accept an already-accepted call (double-tap) | Second tap fails gracefully (409), no duplicate channel join | |
| 93 | App goes to background during call | Audio continues | |

---

## 11. Chat

| # | Action | Expected result | Result |
|---|--------|-----------------|--------|
| 94 | Client opens chat with a handyman | Chat room loads with message history | |
| 95 | Send a text message | Message appears on sender side; recipient receives it in real-time | |
| 96 | Recipient replies | Message appears on both sides | |
| 97 | Navigate away and back to chat | Messages still visible | |

---

## 12. Notifications

| # | Action | Expected result | Result |
|---|--------|-----------------|--------|
| 98 | Receive a booking request (as handyman) | Push notification shown; tapping opens booking | |
| 99 | Receive a booking update (as client) | Push notification shown; tapping opens booking | |
| 100 | Receive an incoming call notification | Tapping opens incoming call screen | |
| 101 | Open notifications page | All past notifications listed, unread ones highlighted | |
| 102 | Tap a notification | Navigates to correct screen (booking / call / chat) | |
| 103 | Mark all as read | All notifications show as read | |

---

## 13. Admin Panel

| # | Action | Expected result | Result |
|---|--------|-----------------|--------|
| 104 | Login with admin account | Admin home shown (not client/handyman home) | |
| 105 | Open User Management | List of users (clients + handymen) loaded | |
| 106 | Suspend a handyman | Handyman account suspended; they can't access app features | |
| 107 | Approve a pending handyman | Handyman status changes to approved | |
| 108 | Open Analytics page | Charts/stats load without crash | |
| 109 | Open Admin Notifications | Notifications list visible | |

---

## 14. Offline / Edge Cases

| # | Action | Expected result | Result |
|---|--------|-----------------|--------|
| 110 | Disable internet, open app | Cached data shown (profile, bookings, favorites) | |
| 111 | Re-enable internet | Data refreshes automatically | |
| 112 | Force-close app and reopen | User stays logged in, correct home screen shown | |
| 113 | Switch between light and dark mode | All screens render correctly in both modes | |
| 114 | Switch language (EN / AR / FR) | App text changes; no overflow or missing strings | |
| 115 | Open app on a device with slow network | Loading indicators shown; no silent failures | |

---

## 15. Security Spot-checks

| # | Action | Expected result | Result |
|---|--------|-----------------|--------|
| 116 | Inspect Firestore during a call initiation | No Agora tokens written to `/calls` docs | |
| 117 | Try to access `/api/calls/:id/accept` as the caller (not callee) | 403 Forbidden | |
| 118 | Try to call a user without a confirmed booking | 403 Forbidden | |
| 119 | Inspect Firestore client doc | Phone is stored in `favoriteHandymen` field (not `favorites`) | |
| 120 | Check handyman doc after disabling phone reveal | `showPhoneNumber: false` in Firestore | |

---

## Results Summary

| Section | Total | Pass | Fail | Skip |
|---------|-------|------|------|------|
| 1. Authentication | 20 | | | |
| 2. Client Home | 5 | | | |
| 3. Handyman Details | 12 | | | |
| 4. Favorites Page | 7 | | | |
| 5. Client Bookings | 4 | | | |
| 6. Client Profile | 5 | | | |
| 7. Map | 3 | | | |
| 8. Handyman Settings | 15 | | | |
| 9. Booking Lifecycle | 6 | | | |
| 10. Calling | 14 | | | |
| 11. Chat | 4 | | | |
| 12. Notifications | 6 | | | |
| 13. Admin | 6 | | | |
| 14. Offline/Edge | 6 | | | |
| 15. Security | 5 | | | |
| **Total** | **118** | | | |

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
