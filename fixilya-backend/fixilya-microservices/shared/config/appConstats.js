const APP_CONSTANTS = {
  USER_TYPES: ["client", "customer", "handyman", "admin"],


  //ANCHOR - Token settings
  TOKEN_EXPIRATION: "1h",
  REFRESH_TOKEN_EXPIRATION: "7d",
  FIREBASE_TOKEN_EXPIRATION: 3600, // 1 hour in seconds
  
  
  //ANCHOR - Firestore collection names
  USER_COLLECTION_NAME: "users",
  HANDYMAN_COLLECTION_NAME: "handymen",
  CLIENT_COLLECTION_NAME: "clients",
  BOOKING_COLLECTION_NAME: "bookings",
  NOTIFICATION_COLLECTION_NAME: "notifications",
  CUSTOMER_COLLECTION_NAME: "customers",
  ADMIN_NOTIFICATIONS_COLLECTION_NAME : "adminNotifications",

  SINGLE_HANDYMAN_TYPE : "handyman",
  SINGLE_CLIENT_TYPE : "client",
  
  //ANCHOR - Default values
  DEFAULT_PROFILE_PICTURE: "https://example.com/default-profile-picture.png",
  DEFAULT_USER_TYPE: "customer",
  DEFAULT_USER_ROLE: "customer",
};

module.exports = APP_CONSTANTS;
