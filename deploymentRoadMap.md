# Fixilya — Production Deployment Roadmap

**App:** Fixilya — Handyman Services Marketplace
**Stack:** Flutter (Android) + Node.js microservices + Firebase + Nginx
**Target:** Google Play Store + self-hosted VPS backend 

---

## PART 1 — Backend Deployment (Server)

### Step 1 — Get a Server (VPS)

You need a Linux VPS. Recommended options:

| Provider | Plan | Price | Notes |
|---|---|---|---|
| **Hetzner** | CX22 (2 vCPU, 4 GB RAM) | ~€4/mo | Best value |
| **DigitalOcean** | Basic Droplet (2 vCPU, 2 GB) | ~$12/mo | Good |
| **Contabo** | VPS S (4 vCPU, 6 GB) | ~€5/mo | Good |

**Minimum required:** 2 vCPU, 4 GB RAM (7 services + Redis + Nginx).
**OS:** Ubuntu 24.04 LTS.

---

### Step 2 — Point Your Domain to the Server

In your domain registrar DNS settings, add an A record:

```
Type:  A
Name:  api
Value: YOUR_SERVER_IP
TTL:   300
```

Verify after 5–15 minutes:
```bash
ping api.fixilya.ma
# Should return your server IP
```

---

### Step 3 — Initial Server Setup

SSH into your server:
```bash
ssh root@YOUR_SERVER_IP
```

Run:
```bash
# Update system
apt update && apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sh

# Install Docker Compose plugin
apt install docker-compose-plugin -y

# Install Certbot (for HTTPS/SSL)
apt install certbot -y

# Verify
docker --version
docker compose version
```

---

### Step 4 — Upload Backend Code to the Server

**Option A — SCP (copy from local machine):**
```bash
# Run this on your LOCAL machine, not the server
scp -r "C:/Users/Windows/OneDrive/Bureau/fixilya_app/fixilya-backend" root@YOUR_SERVER_IP:/opt/fixilya-backend
```

**Option B — Git (recommended for updates):**
```bash
# On the server
cd /opt
git clone https://github.com/YOUR_USERNAME/fixilya_app.git fixilya
```

---

### Step 5 — Create `.env` Files for Each Service

SSH into the server, then navigate to the microservices folder:
```bash
cd /opt/fixilya-backend/fixilya-microservices
```

**How to get the Firebase private key:**
1. Firebase Console → your `fixilya-app` project → gear icon → Project settings → Service accounts
2. Click **Generate new private key** → download the JSON file
3. From the JSON, copy: `project_id`, `client_email`, `private_key`

---

**5.1 — auth-service**
```bash
nano services/auth-service/.env
```
```env
NODE_ENV=production
PORT=3001

FIREBASE_PROJECT_ID=fixilya-app
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nYOUR_KEY_HERE\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-XXXXX@fixilya-app.iam.gserviceaccount.com

JWT_SECRET=your_very_long_random_secret_minimum_32_chars

REDIS_URL=redis://redis:6379

SENDGRID_API_KEY=SG.your_sendgrid_key_here

AGORA_APP_ID=100dfbc4a86d4affbe7eaabe0808a6d8
AGORA_APP_CERTIFICATE=YOUR_AGORA_CERTIFICATE_HERE
```

**5.2 — user-service**
```bash
nano services/user-service/.env
```
```env
NODE_ENV=production
PORT=3002
AUTH_SERVICE_URL=http://auth-service:3001

FIREBASE_PROJECT_ID=fixilya-app
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nYOUR_KEY_HERE\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-XXXXX@fixilya-app.iam.gserviceaccount.com

REDIS_URL=redis://redis:6379
```

**5.3 — booking-service**
```bash
nano services/booking-service/.env
```
```env
NODE_ENV=production
PORT=3003
AUTH_SERVICE_URL=http://auth-service:3001
NOTIFICATION_SERVICE_URL=http://notification-service:3005

FIREBASE_PROJECT_ID=fixilya-app
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nYOUR_KEY_HERE\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-XXXXX@fixilya-app.iam.gserviceaccount.com

REDIS_URL=redis://redis:6379
```

**5.4 — notification-service**
```bash
nano services/notification-service/.env
```
```env
NODE_ENV=production
PORT=3005

FIREBASE_PROJECT_ID=fixilya-app
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nYOUR_KEY_HERE\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-XXXXX@fixilya-app.iam.gserviceaccount.com

REDIS_URL=redis://redis:6379
```

**5.5 — call-service**
```bash
nano services/call-service/.env
```
```env
NODE_ENV=production
PORT=3007

FIREBASE_PROJECT_ID=fixilya-app
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nYOUR_KEY_HERE\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-XXXXX@fixilya-app.iam.gserviceaccount.com

AGORA_APP_ID=100dfbc4a86d4affbe7eaabe0808a6d8
AGORA_APP_CERTIFICATE=YOUR_AGORA_CERTIFICATE_HERE

REDIS_URL=redis://redis:6379
```

**5.6 — media-service**
```bash
nano services/media-service/.env
```
```env
NODE_ENV=production
PORT=3006
AUTH_SERVICE_URL=http://auth-service:3001

CLOUDINARY_CLOUD_NAME=dbz3wtlbj
CLOUDINARY_API_KEY=YOUR_CLOUDINARY_API_KEY
CLOUDINARY_API_SECRET=YOUR_CLOUDINARY_API_SECRET
```

**5.7 — payment-service**
```bash
nano services/payment-service/.env
```
```env
NODE_ENV=production
PORT=3004
AUTH_SERVICE_URL=http://auth-service:3001
```

---

### Step 6 — Obtain SSL Certificate

```bash
# Get certificate (port 80 must be free)
certbot certonly --standalone -d api.fixilya.ma

# Certificates will be saved at:
# /etc/letsencrypt/live/api.fixilya.ma/fullchain.pem
# /etc/letsencrypt/live/api.fixilya.ma/privkey.pem
```

The `nginx.conf` and `docker-compose.yml` in this repo are already configured to:
- Redirect HTTP (port 80) to HTTPS (port 443)
- Mount `/etc/letsencrypt` into the Nginx container
- Use your certificate at the path above

---

### Step 7 — Create Dockerfiles for Each Service

Only `call-service` ships with a Dockerfile. Run this on the server to create one for every service:

```bash
cd /opt/fixilya-backend/fixilya-microservices/services

for SERVICE in auth-service user-service booking-service payment-service notification-service media-service; do
  cat > $SERVICE/Dockerfile << 'EOF'
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY . .
CMD ["node", "src/app.js"]
EOF
done
```

---

### Step 8 — Deploy All Services

```bash
cd /opt/fixilya-backend/fixilya-microservices

# Build images and start all containers
docker compose up -d --build

# Watch startup logs
docker compose logs -f

# Verify all services are running
docker compose ps
# All entries should show status: running
```

Test the gateway is reachable:
```bash
curl https://api.fixilya.ma/health
# Expected: {"status":"healthy","gateway":"nginx"}
```

---

### Step 9 — Set Up SSL Auto-Renewal

Let's Encrypt certificates expire every 90 days. Automate renewal:

```bash
# Test that renewal works
certbot renew --dry-run

# Add monthly cron job
crontab -e
# Add this line:
0 3 1 * * certbot renew --quiet && docker compose -f /opt/fixilya-backend/fixilya-microservices/docker-compose.yml restart nginx
```

---

### Step 10 — Firestore Security Rules

In Firebase Console → Firestore → Rules, replace the default rules with:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    match /handymen/{uid} {
      allow read: if true;
      allow write: if false; // backend only (Admin SDK)
    }

    match /clients/{uid} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }

    match /bookings/{bookingId} {
      allow read: if request.auth != null &&
        (resource.data.clientId == request.auth.uid ||
         resource.data.handymanId == request.auth.uid);
      allow write: if false; // backend only
    }

    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

---

## PART 2 — Flutter App Build & Play Store

### Step 11 — Create the Release Keystore

Run once on your local machine. Store the `.jks` file somewhere safe — **losing it means you can never update the app on Play Store.**

```bash
keytool -genkey -v \
  -keystore C:/Users/Windows/fixilya-release.jks \
  -storetype JKS \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias fixilya-key
```

Fill in the prompts (country: MA, organization: Fixilya SARL). Remember both passwords.

---

### Step 12 — Create `android/key.properties`

```bash
# Create the file
nano C:/Users/Windows/OneDrive/Bureau/fixilya_app/android/key.properties
```

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=fixilya-key
storeFile=C:/Users/Windows/fixilya-release.jks
```

Verify it is in `.gitignore` (never commit this file):
```bash
grep "key.properties" android/.gitignore
# If not printed, add it:
echo "key.properties" >> android/.gitignore
```

---

### Step 13 — Restrict the Google Maps API Key

Your key is hardcoded in `AndroidManifest.xml`. Restrict it to prevent abuse:

1. Get your app's SHA-1 fingerprint:
```bash
keytool -list -v \
  -keystore C:/Users/Windows/fixilya-release.jks \
  -alias fixilya-key
# Copy the SHA1 value
```

2. Go to [Google Cloud Console](https://console.cloud.google.com) → APIs & Services → Credentials
3. Open the key `AIzaSyBdq090XX4rOcdOG2KLsA0dWcBwHt9PIXA`
4. Application restrictions → **Android apps** → Add:
   - Package name: `com.fixilya.app`
   - SHA-1: paste from above
5. Save

---

### Step 14 — Configure Firebase for Production

**Add SHA fingerprints to Firebase:**
1. Firebase Console → Project settings → your Android app → **Add fingerprint**
2. Add both SHA-1 and SHA-256 (get SHA-256 from the same `keytool -list` output)

**Authorize your API domain:**
1. Firebase Console → Authentication → Settings → **Authorized domains**
2. Add `api.fixilya.ma`

---

### Step 15 — Build the Production AAB

```bash
cd C:/Users/Windows/OneDrive/Bureau/fixilya_app

flutter clean
flutter pub get

flutter build appbundle --release \
  --dart-define=AUTH_SERVICE_URL=https://api.fixilya.ma/api/auth \
  --dart-define=USER_SERVICE_URL=https://api.fixilya.ma/api/users \
  --dart-define=BOOKING_SERVICE_URL=https://api.fixilya.ma/api/bookings \
  --dart-define=NOTIFICATION_SERVICE_URL=https://api.fixilya.ma/api/notifications \
  --dart-define=CALL_SERVICE_URL=https://api.fixilya.ma/api/calls \
  --dart-define=AGORA_APP_ID=100dfbc4a86d4affbe7eaabe0808a6d8
```

Output file location:
```
build/app/outputs/bundle/release/app-release.aab
```

---

### Step 16 — Create a Google Play Developer Account

1. Go to [play.google.com/console](https://play.google.com/console)
2. Pay the one-time **$25** registration fee
3. Complete your developer profile
4. Accept the Developer Distribution Agreement

---

### Step 17 — Create the App in Play Console

1. Click **Create app**
2. App name: **Fixilya**
3. Default language: **English**
4. Type: **App**
5. Free or Paid: **Free**
6. Accept policies → **Create app**

---

### Step 18 — Fill in the Store Listing

Go to **Store presence → Main store listing**:

| Field | Value |
|---|---|
| App name | Fixilya |
| Short description (80 chars) | Connect with trusted handymen near you — book, chat, and call in one app |
| Full description | Describe the app: booking, services, Morocco coverage, 3 languages |
| App icon | 512×512 PNG, no transparency |
| Feature graphic | 1024×500 PNG |
| Screenshots | Minimum 2 phone screenshots at 1080×1920 |

---

### Step 19 — Fill in App Content Declarations

**Privacy Policy:**
- Generate one at [privacypolicygenerator.info](https://privacypolicygenerator.info)
- Host it on your website or GitHub Pages
- Add the URL in Play Console → App content → Privacy policy

**App content questionnaire:**
- Ads: No
- Content rating: complete the questionnaire (result should be Everyone / PEGI 3)
- Target audience: 18+
- Data safety — declare what you collect:
  - Location (approximate + precise): yes, for showing nearby handymen
  - Name, email, phone: yes, for account
  - Photos/videos: yes, uploaded by users
  - Audio: yes, for in-app calls

---

### Step 20 — Internal Testing First

Do not publish to production immediately. Use internal testing:

1. **Testing → Internal testing → Create new release**
2. Upload `app-release.aab`
3. Add release notes: *Initial release*
4. **Save → Review release → Start rollout**
5. Add your own email and team members as testers
6. Testers install via the Play Store link sent to them
7. Test for 1–3 days. Fix any issues, rebuild with incremented version, upload again.

---

### Step 21 — Promote to Production

Once internal testing passes:

1. **Testing → Internal testing** → find your release
2. **Promote release → Production**
3. Set rollout: start at **20%** (safer — limits exposure if a bug slips through)
4. **Start rollout to Production**

Google reviews the first submission — usually **1–3 business days**.

---

## PART 3 — Ongoing Operations

### Updating the Backend

```bash
ssh root@YOUR_SERVER_IP
cd /opt/fixilya-backend/fixilya-microservices

# Pull latest code
git pull

# Rebuild only changed services (others stay up)
docker compose up -d --build auth-service
docker compose up -d --build user-service
# etc.
```

### Releasing an App Update

1. Increment version in `pubspec.yaml` — build number must always increase:
   ```yaml
   version: 1.0.1+3   # was 1.0.0+2
   ```
2. Run the build command from Step 15
3. Play Console → Production → **Create new release** → upload new `.aab`

### Monitoring

- **Crash reports:** Firebase Console → Crashlytics (add `firebase_crashlytics` package to get dart-side crashes)
- **Server logs:** `docker compose logs -f` or `docker compose logs --since=2h`
- **Play Console → Android vitals:** ANRs and crashes from real users

---

## Final Checklist

```
BACKEND
[ ] VPS provisioned (Ubuntu 24.04, min 2 vCPU / 4 GB RAM)
[ ] Domain api.fixilya.ma A record pointing to server IP
[ ] Docker + Docker Compose installed on server
[ ] .env files created for all 7 services with real credentials
[ ] Firebase service account private key in each .env
[ ] Agora App Certificate in auth-service and call-service .env
[ ] Dockerfiles created for all services (Step 7)
[ ] SSL certificate obtained via Certbot for api.fixilya.ma
[ ] docker compose up -d --build ran without errors
[ ] docker compose ps shows all services as running
[ ] curl https://api.fixilya.ma/health returns 200
[ ] SSL auto-renewal cron job configured
[ ] Firestore security rules updated (no open read/write)

FLUTTER APP
[ ] Release keystore created and stored safely (NOT in git)
[ ] android/key.properties created with correct paths and passwords
[ ] key.properties confirmed in android/.gitignore
[ ] Google Maps API key restricted to com.fixilya.app + SHA-1
[ ] SHA-1 and SHA-256 added to Firebase Android app settings
[ ] api.fixilya.ma added to Firebase Auth authorized domains
[ ] flutter build appbundle --release succeeds with --dart-define URLs
[ ] .aab installed and tested on real device via internal testing track
[ ] Store listing complete: icon, feature graphic, screenshots, description
[ ] Privacy policy URL provided
[ ] Content rating questionnaire completed
[ ] Data safety section filled in
[ ] Promoted to production at 20% rollout
```
