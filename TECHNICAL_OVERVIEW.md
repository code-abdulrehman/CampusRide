# CampusRide — Technical Overview

> Status of the actual code in this repository. Everything below was verified against the source
> at the time of writing. Items are labeled **Built**, **Partially Built**, **Planned** (in README only),
> or **Recommended** (proposed here). Nothing is claimed as working unless it exists in code.

---

## 1. Current Build Status

**Verified codebase facts:**
- ~4,900 lines of Dart (`lib/` + `test/`)
- **10 model files** (8 entity classes + 9 enums)
- **18 screens**, **2 shared widget files**, **1 state provider**, **1 data repository**
- **2 widget tests** (boot flow + smart matching) — `flutter analyze` clean, `flutter test` passing
- Deps: `provider`, `intl`, `cupertino_icons` only
- Platforms enabled: Android, iOS, macOS (confirmed `build/macos` and `build/android` succeed)

### Already Built (functional in-app, all mock/in-memory)

| Module | What exists |
|---|---|
| Auth | Register, login, logout. Login ignores password (see Authentication). Demo accounts seeded |
| Student/Driver/Vehicle verification | Status flags that flip instantly (no document/OTP flow) |
| Vehicles | Register vehicle, list own vehicles, pending/verified status |
| Ride offers | Create ride with route (campus dropdowns), date, time, seats, contribution, conditions, notes, recurring flag |
| Ride requests | Post requirement (route, window, seats, budget) |
| Ride search | By from/to campus, date, time window, seats |
| Smart matching | Weighted score (route 30 / time 25 / pickup 15 / budget 10 / rating 10 / reliability 10) → `92% Match` badges |
| Booking lifecycle | Request → accept/reject → PIN check-in → start → complete → rate; cancel restores seat; no-show flag |
| Ratings | Star rating (overall, punctuality, behaviour, communication) |
| Reports | Submit report (9 reasons), admin review (warning / suspend / ban) |
| Notifications | In-app notification list + unread badges (no push) |
| Safety | Ride PIN, SOS screen (mock), emergency contact, institute security contact |
| Admin dashboard | Stats grid, popular routes, student/driver/vehicle verification, report handling, suspend user |

### Partially Built
| Item | Gap |
|---|---|
| Booking flow | No waitlist, no rejected-seat rematch, no cancellation history ledger |
| Recurring rides | Flag + day selector stored, but **no future rides are generated** |
| Cost sharing | Contribution value + suggested split stored, no calculator (distance/fuel/toll) |
| Driver reliability | Score computed from counts but not fed back into booking decisions |

### Missing / Not Built
- Real backend, database, or API call of any kind (verified: **zero** http/supabase/firebase/maps/websocket usage in code)
- Persistence — **in-memory only**: app restart wipes all data (`DataRepository` singleton)
- Real authentication (no OTP, no password check, no tokens)
- Push notifications (FCM)
- Maps, location, geocoding, route geometry
- Live location sharing
- Payments (cash-estimate only)
- Profile picture upload / document storage

---

## 2. Architecture

| Layer | Current | Recommended |
|---|---|---|
| Frontend | Flutter 3.47 / Dart 3.13, Material 3, `provider` (ChangeNotifier) | Same |
| Backend | **None** (frontend only) | Custom REST API (see §7) |
| Database | **None** (in-memory `Map` collections) | PostgreSQL (Supabase or self-hosted) |
| Authentication | Mock email lookup, password ignored | JWT + institute email + OTP (Supabase Auth or custom) |
| Hosting/deployment | Local only (`flutter run`) | Backend on existing server; `flutter build` APK/appbundle + App/Play console |
| Third-party services | None | FCM (push), OSM/Nominatim (maps), optional Supabase |

```
Flutter App (all logic client-side today)
   └── AppStateProvider (ChangeNotifier)
          └── DataRepository (singleton, in-memory Maps) + seedDemoData()
```

---

## 3. Data Sources

- **Local/static:** `Campus.sampleCampuses` (4 campuses) — compile-time const list.
- **Mock/seeded (in-memory, per launch):** 5 users, 2 vehicles, 2 rides, 1 ride request, 2 notifications.
- **User-generated (in-memory only):** everything the user creates (rides, bookings, ratings, reports) lives in `DataRepository` Maps and is lost on restart.
- **Database:** none.
- **External APIs:** none.
- **Maps/location:** none. Recommended for MVP: OpenStreetMap + Nominatim (free, no API key) for pickup/destination search and display; Google Maps later only if needed.

---

## 4. Backend Integration

- **API integration status:** 0%. UI talks directly to `DataRepository` via `AppStateProvider`; there is no `http`, no API client, no models with `fromJson/toJson` used by any remote service.
- **Is a custom backend needed?** Yes — the app is MVP-UI complete but stateless. A backend is required to persist data, verify users, match rides server-side, send notifications, and later track live location.
- **How the frontend should communicate:** REST over HTTPS with JSON. Replace `DataRepository` internals with a thin `ApiClient`; **keep the provider API identical** so no screen code changes.
  - Refactor plan: create `lib/services/api_client.dart` implementing the same methods as `DataRepository` (login, createRide, requestSeat…), backed by `http`. Add `SharedPreferences` to persist the session token between launches.
- **Recommended folder structure (additions):**
  ```
  lib/
    services/
      api_client.dart        # HTTP calls to backend
      location_updater.dart  # live location beacon (see §9)
    models/                  # reuse existing enums/models; add fromJson/toJson
      user.dart              # + toJson needed
      ride.dart              # + ServerRide for API shape
      ...
    config/
      app_config.dart        # reads backend URL + keys
  ```
- **Environment variables / config:** create `.env` (backend) and `--dart-define` for the app:
  - `API_BASE_URL` (required)
  - `MAPS_PROVIDER=nominatim` and OSM endpoint (recommended)
  - `SUPABASE_URL` + `SUPABASE_ANON_KEY` (if Supabase route is chosen)
  - Never commit secrets; use `--dart-define=API_BASE_URL=...` in build/run commands.

---

## 5. API Design Decision — REST vs GraphQL

**Recommendation: REST.**

Reasoning for this project:
- Client needs simple CRUD on ~10 entities (users, rides, bookings, ratings, reports, location). No deeply nested, N+1-prone graphs today.
- REST + OpenAPI generates testable docs and typed clients easily; the Flutter team's tooling around REST (`http`, `dio`) is mature.
- GraphQL adds schema/type complexity, a client layer (`graphql_flutter`), caching decisions, and server tooling for zero benefit at this MVP size.
- If future features need flexibility (timetable-aware suggestions, analytics dashboards), the backend can add dedicated query/dashboard endpoints without rewriting to GraphQL.

**Decision: REST is enough. Do not add GraphQL.**

---

## 6. API Documentation

Recommended practical setup:
- **OpenAPI 3 (Swagger)** spec authored first (or generated from Express routes via `swagger-autogen` / `express-openapi-validator`), served at `/docs` with Swagger UI. This is the single source of truth and lets you test every endpoint in-browser.
- **Typed request/response models:** define TS interfaces (backend) and mirror them as Flutter models with `fromJson`/`toJson`; a mismatch is caught by the compiler, not at runtime.
- **Generated API clients:** for MVP, skip codegen (openapi-generator for Dart adds friction). Hand-write a small `ApiClient` — the endpoint set is small (~14 endpoints). Revisit only if the API grows large.
- **Validation schemas:** use `zod` (TypeScript) or JSON Schema on the server. Validate **every** body/query/param; return `400` with a uniform `{ error, field? }` shape.

---

## 7. Custom Backend & Hosting (on infrastructure you already have)

Assumption: you have (or can provision) a Linux VPS/server. This repo contains **no server code yet** — the following is a plan, not existing code.

| Concern | Recommendation |
|---|---|
| API server | Node.js + Express (TypeScript) — matches README stack, huge ecosystem. Alternative: Dart `shelf` (same language as the app, zero new toolchain) |
| Database | PostgreSQL 16 on the server, or managed Supabase Postgres. Use a connection pooler (pgBouncer) later if needed |
| Authentication | JWT (access 15 min + refresh), `bcrypt`/`argon2` password hashing. For MVP keep institute-email login + admin-marks-verified; OTP in later phase |
| File/document storage | Server disk or S3-compatible (MinIO) bucket for licence/registration uploads behind admin-only access |
| Deployment | PM2 or `systemd` behind **Caddy or Nginx** (auto TLS via Let's Encrypt) + Docker optional. DB backup with `pg_dump` cron |
| Logging | `pino` structured logs to stdout; forward to files/`journald`; error tracking via Sentry later |
| Security basics | HTTPS only, rate limiting (`express-rate-limit`), helmet, CORS locked to app domain, parameterized SQL, per-row RLS if Supabase, secrets via env |
| API versioning | URL versioning: `/api/v1/...` from day one; version bumps are opt-in for clients |

---

## 8. Location Features — Where Location Matters

| Feature | Needs location? | When |
|---|---|---|
| Pickup point selection | Yes (choose gate/point; store lat/lng) | Ride create / booking |
| Destination | Yes (campus lat/lng — static lookup, no live GPS needed) | Ride create/search |
| Route matching | **Not for MVP** — campus-to-campus IDs already give exact routes (§13 of README) | Later: real route overlap via OSM |
| Nearby rides | Yes — and actually **not required for MVP** because search is filtered by source campus already | Later |
| Ride start/end | Yes — record location when ride starts/completes | At events only |
| Live location sharing | Yes — periodic beacon during active ride (§9) | During active ride |

MVP simplification: only **pickup point (lat/lng)** and **live beacon** need device GPS. Everything else is campus-ID based.

---

## 9. Live Location Design (MVP — simple, no real-time infra)

Goal: passenger can see *roughly where the driver is*. Not turn-by-turn, not seconds-accurate.

### Data sent by app (every T seconds, active ride only)
Body of `POST /api/v1/rides/:rideId/location`:
```json
{
  "rideId": "r123",
  "userId": "u456",
  "latitude": 31.5204,
  "longitude": 74.3587,
  "timestamp": "2026-09-16T08:12:34Z"
}
```

### API endpoint design
- `POST /rides/:rideId/location` — upsert latest point (driver/authenticated passenger of that ride only).
- `GET /rides/:rideId/location` — returns latest point per user for that ride (authorized participants).
- No geo-isolation, no history required for MVP (optionally store last 60 points for post-ride review).

### Database / cache strategy
- Single Postgres table `ride_locations (ride_id, user_id, lat, lng, ts, PRIMARY KEY(ride_id, user_id))` via `INSERT ... ON CONFLICT DO UPDATE`.
- **No Redis needed** for MVP. If polling volume grows, cache the latest row in Redis with a 30s TTL read from a cache-first handler.

### How passengers receive updated location
Short **polling**: passenger app calls `GET .../location` every 10–15 s while ride screen is open. Simple, works everywhere, no infra.

### Polling vs WebSocket/SSE
| Option | Complexity | Verdict |
|---|---|---|
| HTTP polling | Trivial | **Use for MVP** |
| SSE | Medium (long-lived conn, proxies) | Defer |
| WebSocket | Higher (state mgmt, reconnects) | Only if real-time chat or turn-by-turn comes |

### Interval recommendation
**Fixed 10 seconds** for MVP.
- 5 s: ~45% more requests/battery for no visible UX gain at this fidelity.
- 10 s: good balance; a moving car covers ~150 m, which is acceptable for “driver approaching” UX.
- Adaptive (e.g. 15 s on straight highways, 5 s near destination) — **planned later**, not now.

### Battery / network considerations
- Only run the beacon when `RideStatus == started` and app is foreground.
- Use `geolocator` GPS (balanced accuracy), not background mode; stop beacon on `completed`/`cancelled`.
- Stop location updates immediately when the ride screen is closed (do not keep Fuchsia/background services in MVP).

### When tracking starts / stops
- **Start:** driver taps “Start Ride”.
- **Stop:** “Complete Ride” (or ride cancelled/expired).

### Permission & privacy
- Ask for `LocationWhenInUse` only at ride start, with in-app explanation.
- Location visible **only to ride participants**; never shown on public profiles (§43 of README privacy rules).
- Backend enforces: only users with an accepted booking on `rideId` may read that ride's location.

---

## 10. Suggested API Endpoints

```text
POST   /api/v1/auth/login                      # institute email + password → JWT
POST   /api/v1/auth/register                   # student signup
GET    /api/v1/users/me                        # current profile
PATCH  /api/v1/users/me                        # update profile / emergency contact
POST   /api/v1/vehicles                        # register vehicle
GET    /api/v1/vehicles/me                     # my vehicles
POST   /api/v1/rides                           # offer a ride
GET    /api/v1/rides                           # search (fromCampusId, toCampusId, date, window, seats)
GET    /api/v1/rides/:id                       # ride detail
POST   /api/v1/rides/:id/book                  # passenger requests seat
POST   /api/v1/bookings/:id/accept             # driver accepts
POST   /api/v1/bookings/:id/reject             # driver rejects
POST   /api/v1/bookings/:id/cancel
POST   /api/v1/bookings/:id/checkin            # PIN verify
POST   /api/v1/rides/:id/start
POST   /api/v1/rides/:id/location              # live beacon (lat, lng, ts)
GET    /api/v1/rides/:id/location              # latest points for participants
POST   /api/v1/rides/:id/complete
POST   /api/v1/rides/:id/rate                  # rating POST (overall/punctuality/behaviour/communication)
POST   /api/v1/reports
GET    /api/v1/admin/*                         # admin-only (verify, suspend, stats) with role check
```

---

## 11. Recommended Technical Stack

| Concern | Recommendation |
|---|---|
| Backend | Node.js + Express (TypeScript) — or Dart `shelf` if you want one language end-to-end |
| Database | PostgreSQL |
| API style | REST (JSON), versioned `/api/v1` |
| Swagger/OpenAPI | OpenAPI 3 spec + Swagger UI at `/docs` |
| Validation | `zod` schemas on server, mirrored typed models in Flutter |
| Authentication | JWT (access+refresh), bcrypt/argon2; institute email + OTP later |
| Maps | OpenStreetMap + Nominatim for MVP (free, no key); Google Maps optional later |
| Live location | HTTP beacon every 10 s → `ride_locations` table → participant polling every 10–15 s |
| Notifications | FCM via `firebase_messaging`; backend sends via a small queue or direct call |
| Hosting | Your existing server; Caddy/Nginx + PM2/systemd; Supabase only if you prefer managed Postgres+Auth |

---

## 12. Next Development Steps (prioritized)

**Must build now** (unblocks everything else)
- [ ] PostgreSQL schema + migrations (users, vehicles, rides, bookings, ratings, reports, notifications, ride_locations)
- [ ] REST backend: auth (JWT), users, rides, bookings, ratings (see §10)
- [ ] `lib/services/api_client.dart` replacing `DataRepository` internals (keep provider API unchanged)
- [ ] `fromJson`/`toJson` on all Flutter models
- [ ] Session persistence via `SharedPreferences` (stay logged in)

**Should build next**
- [ ] Real password + OTP verification flow (institute email)
- [ ] Driver profile + vehicle document upload (admin review storage)
- [ ] Push notifications (FCM): seat request, accepted, ride started, cancelled (+30 min reminder)
- [ ] Live location beacon (§9) + ride-screen polling UI
- [ ] Waitlist + seat-available notification
- [ ] Recurring ride generation (expand stored pattern into concrete rides)

**Can build later**
- [ ] Real-time layer (SSE/WebSocket) for chat and live tracking upgrades
- [ ] Smart cost calculator (distance, fuel avg, toll, parking)
- [ ] Predefined pickup points + maps UI (OSM)
- [ ] Carpool circles, timetable-aware suggestions, campus event pools
- [ ] Reporting/analytics dashboards (route demand, peak hours, occupancy)

---

*Decisions in this document assume one shared Postgres for all features and a single REST service. Nothing here depends on GraphQL, Redis, Kafka, or multi-service architecture at MVP stage.*