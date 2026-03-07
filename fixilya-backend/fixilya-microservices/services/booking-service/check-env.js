/**
 * Run this FIRST to verify your .env is set up correctly:
 *   node check-env.js
 */
const path = require('path');
const fs   = require('fs');

const ENV_PATH = path.resolve(__dirname, '.env');
console.log('\n🔍 Looking for .env at:', ENV_PATH);

if (!fs.existsSync(ENV_PATH)) {
  console.error('❌ .env NOT FOUND');
  console.error('   Fix: copy .env.example .env  then fill in your values\n');
  process.exit(1);
}

require('dotenv').config({ path: ENV_PATH });

const required = [
  'FIREBASE_PROJECT_ID',
  'FIREBASE_CLIENT_EMAIL',
  'FIREBASE_PRIVATE_KEY',
];

let ok = true;
for (const key of required) {
  const val = process.env[key];
  if (!val) {
    console.error(`❌ Missing: ${key}`);
    ok = false;
  } else {
    // Show only first 30 chars so the key isn't exposed in logs
    console.log(`✅ ${key} = ${val.substring(0, 30)}...`);
  }
}

if (!ok) {
  console.error('\n❌ Fix the missing variables in .env then try again.\n');
  process.exit(1);
}

console.log('\n✅ All environment variables present. Ready to start.\n');