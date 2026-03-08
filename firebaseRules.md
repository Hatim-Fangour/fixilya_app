  rules_version = '2';
  service cloud.firestore {
    match /databases/{database}/documents {

      match /handymen/{uid} {
        allow read: if true;
        allow write: if false;
      }

      match /clients/{uid} {
        allow read, write: if request.auth != null && request.auth.uid == uid;
      }

      match /bookings/{bookingId} {
        allow read: if request.auth != null &&
          (resource.data.clientId == request.auth.uid ||
           resource.data.handymanId == request.auth.uid);
        allow write: if false;
      }

      match /{document=**} {
        allow read, write: if false;
      }
    }
  }