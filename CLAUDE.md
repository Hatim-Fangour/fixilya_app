# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Fixilya is a handyman services marketplace app (Flutter frontend + Node.js microservices backend). Users are either **clients** (book services), **handymen** (provide services), or **admins**. The app targets Morocco (default location: Casablanca, supports EN/AR/FR).

## Build & Run Commands

```bash
# Flutter frontend
flutter pub get
flutter run                          # Debug on connected device/emulator
flutter run --dart-define=AUTH_SERVICE_URL=https://auth.fixilya.ma/api  # Production URLs
flutter build apk --release
flutter build ios --release

# Backend microservices (each service independently)
cd ../fixilya-backend/fixilya-microservices/services/auth-service && npm install && npm start
# Services: auth-service(:3001), user-service(:3002), booking-service(:3003),
#           payment-service(:3004), notification-service(:3005), media-service(:3006)

# Localization (after editing l10n/ files)
flutter gen-l10n
```

## Architecture

### Frontend (lib/)

**State management**: GetX is primary. Global controllers initialized in order in `main.dart`:
1. `ThemeController` → 2. `AuthController` → 3. `UserController` → 4. `LanguageService` → 5. `ServiceLocator.init()` → 6. `ApiClient().init()` → 7. `NotificationService().init()`

**Feature modules** follow Clean Architecture under `lib/features/{feature}/`:
- `presentation/` (screens, controllers, widgets)
- `data/` (models, datasources, repositories)
- `domain/` (entities, repository interfaces, usecases)

Features: `auth`, `client`, `handyman`, `admin`, `booking`, `chat`, `call`, `guest`, `notifications`, `reviews`

**Routing**: GetX named routes defined in `lib/core/constants/app_routes.dart` (~70 routes). `AuthGuard` middleware redirects unauthenticated users. Navigation helpers: `AppRoutes.to()`, `.off()`, `.offAll()`, `.back()`.

**Services** (`lib/services/`): Singletons for API, auth, storage, notifications, location, etc. `ApiClient` uses Dio with Firebase ID token injection, caching (15-min stale-while-revalidate), and 401 auto-retry.

**Page switching**: `WidgetTree` (`lib/views/widget_tree.dart`) uses `selectedPageNotifier` (ValueNotifier) for bottom nav page index.

### Backend (../fixilya-backend/fixilya-microservices/)

Node.js/Express microservices behind Nginx gateway. Each service has `src/{app.js, controllers/, routes/, services/}`. Shared code in `shared/{middleware/, utils/, config/}`.

**Auth model**: Firebase Auth on both frontend and backend. Frontend gets Firebase ID token → injected via Dio interceptor → backend verifies with `firebase-admin`. Backend `shared/middleware/auth.js` handles token verification.

**Database**: Cloud Firestore. Frontend has offline persistence enabled (100MB cache).

### Key Config

- API URLs default to Android emulator loopback (`10.0.2.2:PORT`). Override via `--dart-define`.
- `AppConfig` in `lib/core/config/app_config.dart` centralizes all constants (URLs, limits, feature flags).
- `ServiceLocator` (`lib/services/service_locator.dart`) lazy-loads Cloudinary and Firebase image services via GetX.

## Conventions

- **User types**: `'client'` and `'handyman'` (stored as `userType` field). Each has separate profile setup, home page, and data services.
- **Error handling**: `ApiErrorHandler` class handles DioExceptions globally with snackbar notifications. Backend uses `AppError` class.
- **Image uploads**: Cloudinary (public) for profile/service images, Firebase Storage as fallback.
- **Localization**: 3 languages (EN, AR, FR). Use `AppLocalizations` delegate. Runtime switching via `LanguageService`.
- **Theme**: 3 modes (light/dark/system). `ThemeController` persists preference in `LocalStorageService` (GetStorage).
- **VoIP**: Agora RTC Engine for in-app calling. Tokens generated server-side at `/api/agora/token`.
