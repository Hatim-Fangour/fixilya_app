const admin = require('firebase-admin');

console.log('🔥 Initializing Firebase Admin SDK...');
// console.log('process.env.FIREBASE_PROJECT_ID:', process.env.FIREBASE_PROJECT_ID);
// console.log('process.env.FIREBASE_CLIENT_EMAIL:', process.env.FIREBASE_CLIENT_EMAIL);
// console.log('process.env.FIREBASE_PRIVATE_KEY:', process.env.FIREBASE_PRIVATE_KEY )

// ✅ Verify environment variables
if (!process.env.FIREBASE_PROJECT_ID) {
  console.error('❌ FIREBASE_PROJECT_ID is missing!');
  throw new Error('FIREBASE_PROJECT_ID environment variable is required');
}

if (!process.env.FIREBASE_CLIENT_EMAIL) {
  console.error('❌ FIREBASE_CLIENT_EMAIL is missing!');
  throw new Error('FIREBASE_CLIENT_EMAIL environment variable is required');
}

if (!process.env.FIREBASE_PRIVATE_KEY) {
  console.error('❌ FIREBASE_PRIVATE_KEY is missing!');
  throw new Error('FIREBASE_PRIVATE_KEY environment variable is required');
}

// Initialize Firebase Admin SDK only once
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId: process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
    }),
  });
}

// ✅ CRITICAL: Export auth and db as named exports
const auth = admin.auth();
const db = admin.firestore();

module.exports = admin;
module.exports.auth = auth;
module.exports.db = db;