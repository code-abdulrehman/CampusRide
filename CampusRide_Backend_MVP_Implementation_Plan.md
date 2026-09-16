# CampusRide — Backend MVP Implementation Plan

## 0. Final Architecture Decision

CampusRide ka MVP existing Flutter application ko rewrite nahi karega. Current UI, screens aur `provider` based state management ko retain kiya jayega. Mock/in-memory `DataRepository` ko gradually real backend integration se replace kiya jayega.

Final technical direction:

```text
Flutter App
   |
   |-- REST API ----------> Durable CRUD + business operations
   |
   |-- WebSocket ---------> Realtime events + live location
   |
   |-- Local SQLite ------> Read cache / offline snapshot only
   |
   `-- Static Assets -----> Built-in PNG avatars

Custom Backend
   |
   |-- Node.js + Express + TypeScript
   |-- PostgreSQL
   |-- REST /api/v1
   |-- WebSocket /ws
   |-- OpenAPI / Swagger
   `-- Custom Auth (JWT + Refresh Tokens)
```

### Explicitly NOT included in MVP

- GraphQL
- Firebase Database
- Supabase Database
- Object/file storage
- S3 / MinIO
- User image uploads
- Redis
- Kafka
- Microservices
- Multiple backend databases
- WebSocket for every single CRUD call

The backend will initially run locally and later be deployable to the existing server without changing the Flutter API contracts.

---

## 1. Current App Baseline

Current technical report ke mutabiq app mein already:

- around 4,900 lines of Dart
- 18 screens
- Provider / ChangeNotifier state management
- in-memory `DataRepository`
- ride offers
- ride requests
- weighted matching
- booking lifecycle
- ratings
- reports
- notifications UI
- safety screens
- admin dashboard

already implemented hain, lekin real backend, persistent database, production auth, maps aur WebSocket layer abhi nahi hain.

Is plan ka purpose existing screens ko redesign karna nahi, balkay unko real data layer ke sath connect karna hai.

---

## 2. Core Backend Rule: REST + WebSocket, Not REST vs WebSocket

REST aur WebSocket ko competing technologies nahi samjha jayega.

### REST ka role

REST durable operations aur initial page data ke liye use hoga:

- register/login
- profile fetch/update
- ride create/update/cancel
- ride search ka initial snapshot
- booking request
- booking accept/reject/cancel
- ratings
- reports
- admin operations

### WebSocket ka role

WebSocket realtime changes ko connected users tak immediately push karega:

- new ride relevant search mein appear hona
- ride seats change hona
- booking requested
- booking accepted/rejected
- ride cancelled
- ride started/completed
- verification status update
- realtime notifications
- driver live location

### Critical rule

Durable business state ke liye flow:

```text
Flutter
   |
POST /booking
   |
Backend validation
   |
PostgreSQL transaction
   |
COMMIT
   |
Immediate WebSocket event
   |
Other connected users update UI
```

Is tarah REST operation database mein immediately save hoti hai aur WebSocket same change ko realtime mein broadcast karta hai. Client ko 10 minutes baad poll karne ki zarurat nahi hoti.

### Ephemeral data

Live location jaise high-frequency data ke liye client -> server WebSocket use kiya ja sakta hai directly.

---

## 3. Recommended Backend Stack

| Concern | Decision |
|---|---|
| Runtime | Node.js |
| Language | TypeScript |
| HTTP framework | Express |
| API | REST `/api/v1` |
| Realtime | Raw WebSocket using `ws` |
| Database | PostgreSQL |
| ORM | Prisma, with raw SQL only where advanced locking is required |
| Validation | Zod |
| API docs | OpenAPI + Swagger UI |
| Auth | Custom JWT access + refresh token system |
| Password hashing | Argon2id |
| Flutter HTTP | Dio |
| Flutter WebSocket | `web_socket_channel` |
| Local cache | SQLite/Drift |
| State management | Keep existing Provider |
| Logging | Pino |
| Testing | Vitest/Jest + Supertest + WebSocket integration tests |
| Deployment | Docker Compose + Nginx/Caddy later |

---

## 4. Why PostgreSQL

PostgreSQL should be the primary server database.

CampusRide ka data naturally relational hai:

```text
User
 -> Vehicle
 -> Ride
 -> Booking
 -> Passenger
 -> Rating
 -> Report
```

Important requirements:

- transactions
- row locking
- unique constraints
- relational joins
- admin reporting
- aggregation
- indexes
- future geospatial support

Booking acceptance jaise operations mein multiple users same last seat ko simultaneously request/accept kar sakte hain. PostgreSQL transaction ke andar ride row lock karke double booking prevent ki ja sakti hai.

### MongoDB kyun nahi

MongoDB technically possible hai, lekin is product ka core document-shaped nahi balkay relationship-heavy hai. Booking consistency, reports, ride-user relationships aur analytics ke liye relational model simpler rahega.

### Embedded server DB kyun nahi

SQLite jaisa embedded DB single-device/local-cache ke liye acha hai, lekin multi-user realtime server source-of-truth ke liye PostgreSQL better fit hai.

### Future AI

Agar future mein recommendation embeddings, semantic matching ya AI features add karne hon to PostgreSQL mein pgvector extension add ki ja sakti hai. Is wajah se AI future ke liye alag database abhi introduce karne ki zarurat nahi.

### Future geospatial

Advanced nearby-search ya route-overlap ke waqt PostGIS add ki ja sakti hai. MVP mein simple latitude/longitude enough hai.

---

## 5. No Object Storage

MVP mein object/file storage nahi hogi.

Remove:

```text
S3
MinIO
Firebase Storage
Supabase Storage
Uploaded profile images
Uploaded licence images
Uploaded registration files
```

### Avatar design

Flutter app ke andar predefined PNG assets bundle honge:

```text
app/assets/avatars/avatar_01.png
app/assets/avatars/avatar_02.png
...
app/assets/avatars/avatar_20.png
```

Database user record mein sirf:

```text
avatar_key = "avatar_07"
```

store hoga.

Backend allowed avatar keys validate karega. User apni arbitrary image upload nahi kar sakega.

Benefits:

- storage service nahi
- upload API nahi
- CDN requirement nahi
- image moderation nahi
- file security problem nahi
- simple offline rendering

---

## 6. Auth Strategy

MVP recommendation: custom auth inside the custom backend.

Reason: auth requirements basic hain aur user/role/verification records already PostgreSQL mein hain. Firebase Auth add karne se second identity system introduce hoga.

Architecture ko provider-independent rakhne ke liye internally interface use ki ja sakti hai:

```text
AuthProvider
  |- LocalAuthProvider   <-- MVP
  `- FirebaseAuthProvider <-- possible future adapter
```

### MVP auth flow

```text
Register
  -> create user
  -> password hash
  -> initial STUDENT role
  -> verification status

Login
  -> verify email/password
  -> issue access token
  -> issue refresh token
```

### Token rules

- short-lived access token
- longer refresh token
- refresh token rotation
- refresh tokens hashed in DB
- logout invalidates refresh token
- Flutter stores sensitive token using secure storage

### Roles

```text
STUDENT
ADMIN
SUPER_ADMIN
```

Capabilities status-based hongi:

```text
student_verified
 driver_verified
 vehicle_verified
```

Example:

```text
Verified student + unverified driver
- search ride: allowed
- book ride: allowed
- offer ride: blocked
```

---

## 7. Backend Folder Structure

Project root ke existing app folder ke parallel backend folder banega.

```text
project-root/
|
|-- app/                       # Existing Flutter application
|
`-- backend/
    |
    |-- src/
    |   |-- config/
    |   |   |-- env.ts
    |   |   `-- constants.ts
    |   |
    |   |-- controllers/
    |   |   |-- auth.controller.ts
    |   |   |-- user.controller.ts
    |   |   |-- vehicle.controller.ts
    |   |   |-- ride.controller.ts
    |   |   |-- ride-request.controller.ts
    |   |   |-- booking.controller.ts
    |   |   |-- rating.controller.ts
    |   |   |-- report.controller.ts
    |   |   |-- notification.controller.ts
    |   |   `-- admin.controller.ts
    |   |
    |   |-- routes/
    |   |   |-- auth.routes.ts
    |   |   |-- user.routes.ts
    |   |   |-- vehicle.routes.ts
    |   |   |-- ride.routes.ts
    |   |   |-- ride-request.routes.ts
    |   |   |-- booking.routes.ts
    |   |   |-- rating.routes.ts
    |   |   |-- report.routes.ts
    |   |   |-- notification.routes.ts
    |   |   `-- admin.routes.ts
    |   |
    |   |-- services/
    |   |   |-- auth.service.ts
    |   |   |-- user.service.ts
    |   |   |-- vehicle.service.ts
    |   |   |-- ride.service.ts
    |   |   |-- matching.service.ts
    |   |   |-- booking.service.ts
    |   |   |-- rating.service.ts
    |   |   |-- report.service.ts
    |   |   |-- notification.service.ts
    |   |   `-- admin.service.ts
    |   |
    |   |-- repositories/
    |   |   |-- user.repository.ts
    |   |   |-- vehicle.repository.ts
    |   |   |-- ride.repository.ts
    |   |   |-- booking.repository.ts
    |   |   `-- ...
    |   |
    |   |-- realtime/
    |   |   |-- websocket.server.ts
    |   |   |-- connection-manager.ts
    |   |   |-- subscription-manager.ts
    |   |   |-- realtime-publisher.ts
    |   |   |-- events.ts
    |   |   `-- location.handler.ts
    |   |
    |   |-- middleware/
    |   |   |-- auth.middleware.ts
    |   |   |-- role.middleware.ts
    |   |   |-- validation.middleware.ts
    |   |   |-- rate-limit.middleware.ts
    |   |   `-- error.middleware.ts
    |   |
    |   |-- validators/
    |   |   |-- auth.schema.ts
    |   |   |-- ride.schema.ts
    |   |   |-- booking.schema.ts
    |   |   `-- ...
    |   |
    |   |-- common/
    |   |   |-- errors/
    |   |   |-- utils/
    |   |   |-- pagination/
    |   |   `-- response/
    |   |
    |   |-- app.ts
    |   `-- server.ts
    |
    |-- prisma/
    |   |-- schema.prisma
    |   |-- migrations/
    |   `-- seed.ts
    |
    |-- tests/
    |   |-- unit/
    |   |-- integration/
    |   `-- websocket/
    |
    |-- docs/
    |   `-- openapi.yaml
    |
    |-- .env.example
    |-- package.json
    |-- tsconfig.json
    `-- docker-compose.yml
```

---

## 8. Layer Responsibilities

### Routes

Sirf endpoint + middleware + controller binding.

```text
POST /rides
  -> auth
  -> validation
  -> RideController.create
```

### Controllers

Controller HTTP-specific cheezen handle kare:

- request params
- request body
- response status
- calling service

Controller mein business rules nahi honge.

### Services

Actual business rules services mein:

- create ride
- search rules
- match scoring
- accept booking
- seat management
- cancellation
- rating eligibility

### Repositories

Database access only:

- find
- insert
- update
- transaction helper

### Realtime Publisher

Services directly WebSocket implementation par depend nahi karenge.

Example:

```text
BookingService
    |
    `-> RealtimePublisher.publish(...)
```

Is se later WebSocket implementation replace/scaling karna easier hoga.

### Reusable base utilities

Useful shared classes/functions:

- `ApiError`
- `BaseController` response helpers
- `PaginationHelper`
- `AuthContext`
- `RealtimePublisher`
- `PasswordHasher`
- `TokenService`
- `DateTimeHelper`

Over-generic `BaseService<T>` avoid karein agar woh domain logic ko hide karta ho.

---

## 9. Database Schema — MVP

### users

```text
id UUID PK
email UNIQUE
password_hash
full_name
student_id
role
avatar_key
main_campus_id
student_verified
 driver_verified
account_status
rating_average
completed_rides_count
cancellation_count
no_show_count
created_at
updated_at
```

### campuses

```text
id UUID PK
name
code
address
latitude
longitude
security_contact
active
```

### vehicles

```text
id UUID PK
owner_id FK users
vehicle_type
company
model
year
color
registration_number UNIQUE
total_seats
verification_status
active
created_at
updated_at
```

### rides

```text
id UUID PK
driver_id FK users
vehicle_id FK vehicles
origin_campus_id FK campuses
destination_campus_id FK campuses
departure_at TIMESTAMPTZ
expected_arrival_at TIMESTAMPTZ
available_seats
price_per_seat
pickup_radius_km
max_detour_minutes
conditions JSONB
notes
recurring BOOLEAN
status
version INT
created_at
updated_at
```

`version` realtime reconciliation ke liye useful hai.

### ride_requests

```text
id UUID PK
student_id FK users
origin_campus_id
destination_campus_id
earliest_departure
latest_departure
required_arrival
required_seats
max_budget
max_pickup_distance
status
created_at
updated_at
```

### bookings

```text
id UUID PK
ride_id FK rides
passenger_id FK users
seats
status
checkin_pin_hash
requested_at
accepted_at
cancelled_at
checked_in_at
no_show_at
created_at
updated_at
```

### ratings

```text
id UUID PK
ride_id
reviewer_id
reviewee_id
overall
punctuality
behaviour
communication
comment nullable
created_at
```

### reports

```text
id UUID PK
reporter_id
reported_user_id nullable
ride_id nullable
reason
details
status
admin_action
resolved_by nullable
created_at
resolved_at nullable
```

### notifications

```text
id UUID PK
user_id
type
title
body
data JSONB
read_at nullable
created_at
```

### refresh_tokens

```text
id UUID PK
user_id
token_hash
expires_at
revoked_at nullable
created_at
```

### ride_locations

MVP latest-known location only:

```text
ride_id
user_id
latitude
longitude
accuracy nullable
heading nullable
speed nullable
updated_at

PRIMARY KEY (ride_id, user_id)
```

No full location history required initially.

### audit_logs

Admin/security actions:

```text
id
actor_user_id
action
entity_type
entity_id
metadata JSONB
created_at
```

---

## 10. Important Database Indexes

```text
users(email)
users(student_id)
vehicles(registration_number)
rides(origin_campus_id, destination_campus_id, departure_at, status)
rides(driver_id, departure_at)
bookings(passenger_id, status)
bookings(ride_id, status)
ride_requests(origin_campus_id, destination_campus_id, status)
notifications(user_id, read_at, created_at)
reports(status, created_at)
```

Later nearby matching ke liye PostGIS spatial indexes add kiye ja sakte hain.

---

## 11. Booking Concurrency Rule

Seat booking/acceptance sab se critical transaction hai.

Example: ride par sirf 1 seat remaining hai aur driver ko 2 pending requests almost same waqt accept hoti hain.

Correct flow:

```text
BEGIN
  lock ride row
  verify ride is open
  verify available_seats >= booking.seats
  verify booking still pending
  update booking -> ACCEPTED
  decrement available_seats
COMMIT
```

Second concurrent request transaction ke baad re-check hogi aur seat unavailable hone par fail karegi.

Cancellation of an accepted booking bhi transaction ke andar seat restore karegi.

---

## 12. REST API Endpoints

Base URL:

```text
/api/v1
```

### Health

```text
GET /health
GET /ready
```

### Auth

```text
POST /auth/register
POST /auth/login
POST /auth/refresh
POST /auth/logout
```

### Fast application bootstrap

```text
GET /bootstrap
```

Response can include:

```text
current user
campuses
active ride
upcoming booking
unread notification count
```

Ye app launch ke initial HTTP round-trips reduce karega.

### Users

```text
GET   /users/me
PATCH /users/me
PATCH /users/me/avatar
GET   /users/:id/public
```

Avatar endpoint sirf allowed `avatar_key` accept kare.

### Campuses

```text
GET /campuses
GET /campuses/:id
```

Campuses frequently change nahi karte, is liye app local cache mein preload kar sakti hai.

### Vehicles

```text
GET    /vehicles/me
POST   /vehicles
PATCH  /vehicles/:id
DELETE /vehicles/:id
```

### Ride Offers

```text
POST   /rides
GET    /rides/search
GET    /rides/mine
GET    /rides/:id
PATCH  /rides/:id
POST   /rides/:id/cancel
POST   /rides/:id/start
POST   /rides/:id/complete
```

Example search:

```text
GET /rides/search?
  fromCampusId=...
  &toCampusId=...
  &date=...
  &seats=1
  &startTime=...
  &endTime=...
```

### Ride Requests

```text
POST   /ride-requests
GET    /ride-requests/mine
GET    /ride-requests/:id
PATCH  /ride-requests/:id
POST   /ride-requests/:id/cancel
GET    /ride-requests/:id/matches
```

### Bookings

```text
POST /rides/:rideId/bookings
GET  /bookings/mine
GET  /bookings/:id
GET  /rides/:rideId/bookings

POST /bookings/:id/accept
POST /bookings/:id/reject
POST /bookings/:id/cancel
POST /bookings/:id/checkin
POST /bookings/:id/no-show
```

### Ratings

```text
POST /rides/:rideId/ratings
GET  /users/:id/ratings
```

### Reports

```text
POST /reports
GET  /reports/mine
```

### Notifications

```text
GET   /notifications
PATCH /notifications/:id/read
POST  /notifications/read-all
```

### Location fallback

Live location WebSocket se aayegi, lekin reconnect/fallback ke liye:

```text
GET /rides/:rideId/location/latest
```

### Admin

```text
GET   /admin/dashboard
GET   /admin/users
PATCH /admin/users/:id/status

GET   /admin/drivers/pending
PATCH /admin/drivers/:userId/verification

GET   /admin/vehicles/pending
PATCH /admin/vehicles/:vehicleId/verification

GET   /admin/reports
PATCH /admin/reports/:id
```

---

## 13. REST Response Contract

Uniform response shape:

### Success

```json
{
  "success": true,
  "data": {},
  "meta": null
}
```

### Error

```json
{
  "success": false,
  "error": {
    "code": "RIDE_FULL",
    "message": "No seats are available.",
    "fields": null
  }
}
```

Standard domain error codes Flutter UI ke liye important hain.

Examples:

```text
AUTH_INVALID_CREDENTIALS
AUTH_TOKEN_EXPIRED
USER_NOT_VERIFIED
DRIVER_NOT_VERIFIED
VEHICLE_NOT_VERIFIED
RIDE_NOT_FOUND
RIDE_NOT_OPEN
RIDE_FULL
BOOKING_ALREADY_EXISTS
BOOKING_INVALID_STATE
NOT_RIDE_PARTICIPANT
FORBIDDEN
VALIDATION_ERROR
NETWORK_ERROR (client-side)
```

---

## 14. Idempotency

Time-sensitive actions duplicate nahi honi chahiye agar user double-tap kare ya network retry ho.

Critical POST actions mein client generated request ID/idempotency key use kare:

```text
POST /rides/:id/bookings
Idempotency-Key: uuid
```

Server same key ke duplicate operation ko repeat booking create nahi karne dega.

Use especially for:

- create ride
- request booking
- accept booking
- cancel booking
- complete ride

---

## 15. WebSocket Architecture

Single WebSocket endpoint:

```text
ws://localhost:3000/ws
```

Production:

```text
wss://api.example.com/ws
```

REST aur WebSocket same Node HTTP server/port use kar sakte hain.

### Connection flow

```text
1. App login through REST
2. Access token received
3. WebSocket connect
4. Client sends auth event/token
5. Server validates token
6. Server assigns socket to user
7. Client subscribes to required channels
```

No application data should be sent before socket authentication succeeds.

---

## 16. WebSocket Subscription Channels

### Private user channel

```text
user:{userId}
```

For:

- booking update
- notification
- verification changes
- admin/account status

### Search/route channel

```text
route:{fromCampusId}:{toCampusId}:{date}
```

Search screen initial data REST se load karegi aur phir is route channel ko watch karegi.

New ride create hone par relevant connected users ko immediately event milega.

### Ride channel

```text
ride:{rideId}
```

Only driver + accepted/requesting participants as authorized by policy.

For:

- seat changes
- ride state
- bookings
- live location

### Admin channel

```text
admin
```

Only admin users.

---

## 17. WebSocket Event Envelope

All messages consistent format use karein.

```json
{
  "type": "ride.seats.updated",
  "eventId": "uuid",
  "occurredAt": "2026-09-16T10:00:00Z",
  "entityVersion": 8,
  "data": {
    "rideId": "uuid",
    "availableSeats": 2
  }
}
```

`entityVersion` stale/out-of-order messages ignore karne mein help karega.

---

## 18. Server -> Client Realtime Events

```text
system.connected
system.resync_required

ride.created
ride.updated
ride.cancelled
ride.seats.updated
ride.started
ride.completed

ride_request.created
ride_request.updated
ride_request.cancelled

booking.requested
booking.accepted
booking.rejected
booking.cancelled
booking.checked_in
booking.no_show

notification.created
verification.updated
account.status.updated

location.updated
```

Not every event har user ko broadcast hoga. Relevant room/private user target only.

---

## 19. Client -> Server WebSocket Commands

WebSocket ko CRUD replacement nahi banaya jayega.

Client commands primarily:

```text
auth
subscribe.route
unsubscribe.route
subscribe.ride
unsubscribe.ride
location.update
```

Booking/create ride REST se honge. Server commit ke baad realtime event publish karega.

Reason:

- HTTP status clear
- Swagger documentation
- retry behavior predictable
- idempotency easier
- debugging easier
- database transaction response direct milta hai

WebSocket speed ka benefit live updates ke liye use hoga, not to make every endpoint a custom message protocol.

---

## 20. Search Screen Realtime Design

Flow:

```text
Open Search Screen
   |
GET /rides/search
   |
render current rides
   |
subscribe.route
   |
WebSocket events arrive
   |
patch/remove/add ride locally
```

Example:

- Ahmed creates a ride via REST.
- Backend commits it.
- Backend broadcasts `ride.created` to route room.
- Ali ka already-open search screen instantly ride show karta hai.

Seat update:

- booking accepted
- DB seat decremented
- `ride.seats.updated`
- search results immediately update

Client locally current filters apply karega, e.g. 2 seats required but updated ride has only 1 seat, to result remove ho sakta hai.

---

## 21. Booking Realtime Design

Passenger:

```text
POST /rides/:id/bookings
```

After commit:

```text
booking.requested -> driver private channel
```

Driver accepts:

```text
POST /bookings/:id/accept
```

Transactional seat update ke baad:

```text
booking.accepted -> passenger private channel
ride.seats.updated -> ride + route channel
```

Is flow mein REST ki consistency aur WebSocket ki realtime speed dono milti hain.

---

## 22. Live Location

Live location WebSocket ke liye strongest use case hai.

### Driver payload

```json
{
  "type": "location.update",
  "data": {
    "rideId": "uuid",
    "latitude": 31.1234,
    "longitude": 74.1234,
    "accuracy": 9.2,
    "heading": 210,
    "speed": 12.4,
    "capturedAt": "2026-09-16T10:01:10Z"
  }
}
```

### Server rules

Server verifies:

- socket authenticated
- user is ride driver
- ride status is STARTED
- coordinates valid
- message rate allowed

Then:

1. broadcast to authorized ride participants
2. upsert latest point in `ride_locations`

### Interval

MVP adaptive simple rule:

```text
normal active ride: 10 seconds
near pickup / high-change phase: 5 seconds
```

Do not send faster than server limit unless later testing proves a need.

### No location history initially

Only latest location required. Full GPS trail is unnecessary for current product.

---

## 23. WebSocket Load Protection

To prevent server/app overkill:

- authenticated connections only
- per-user connection limit
- heartbeat ping/pong
- idle disconnect
- max message size
- per-event rate limit
- location throttle
- no global broadcast
- subscription cleanup on disconnect
- connection count metrics

Suggested MVP policy:

```text
max 2-3 active sockets per user
location no faster than ~3 seconds
normal target 5-10 seconds
```

---

## 24. WebSocket Reconnect & Missed Events

Mobile networks disconnect frequently.

Flutter WebSocket service needs:

```text
Disconnected
 -> exponential backoff
 -> reconnect
 -> re-authenticate
 -> re-subscribe channels
 -> REST re-sync current screen
```

Example delays:

```text
1s
2s
4s
8s
15s max
```

with jitter.

### Important

Do not assume WebSocket event history is guaranteed.

On reconnect:

- search screen re-runs `GET /rides/search`
- active ride re-runs `GET /rides/:id`
- location uses `GET /rides/:id/location/latest`
- notifications refetch unread items

This prevents stale UI even if socket missed an event.

---

## 25. Offline Behaviour

No internet should never crash the app.

### Read operations

App can show cached last-known data with clear offline state.

Examples:

- campuses
- own profile
- own vehicles
- last known upcoming rides/bookings
- last loaded notifications

### Time-sensitive writes

Do NOT silently queue these offline:

- book seat
- accept booking
- cancel at last minute
- start ride
- complete ride

Reason: by the time connectivity returns, state may already be invalid.

Instead show:

```text
You are offline. Reconnect to perform this action.
```

### Safe operations

Non-critical profile preferences could be queued later, but not required for MVP.

---

## 26. Flutter Data Layer Changes

Keep current Provider and screens.

Recommended architecture:

```text
UI Screens
    |
AppStateProvider
    |
CampusRideRepository
    |
    |-- ApiClient (Dio)
    |-- RealtimeClient (WebSocket)
    `-- LocalCache (SQLite/Drift)
```

### Existing mock repository

Current in-memory implementation should not be deleted immediately.

Convert it into:

```text
CampusRideRepository interface

Implementations:
- MockCampusRideRepository   # tests/demo
- NetworkCampusRideRepository # production
```

This makes development and testing easier.

---

## 27. Flutter New Files

Suggested additions:

```text
app/lib/
  services/
    api_client.dart
    auth_token_store.dart
    realtime_client.dart
    network_status.dart

  repositories/
    campusride_repository.dart
    mock_campusride_repository.dart
    network_campusride_repository.dart

  cache/
    local_database.dart
    cache_repository.dart

  config/
    app_config.dart

  models/
    # existing models + fromJson/toJson

  realtime/
    realtime_event.dart
    realtime_event_handler.dart
```

---

## 28. Flutter Packages / Capabilities

Recommended capabilities:

- `dio` — REST, interceptors, cancellation, timeouts
- `web_socket_channel` — WebSocket connection
- secure storage — access/refresh token storage as appropriate
- Drift/SQLite — offline read cache
- connectivity awareness — UI signal only; API exceptions remain authoritative

Existing `provider` state management should remain. No Riverpod/BLoC migration is required for backend integration.

---

## 29. API Client Behaviour

Dio client should centralize:

- base URL
- Authorization header
- request ID
- timeout
- token refresh
- standard errors
- logging in development

Do not implement network calls directly in screens.

### Retry policy

Auto retry only safe GET requests initially.

POST booking should not blindly retry unless idempotency key is present.

---

## 30. Fast Page Loading Strategy

Performance should not rely only on WebSocket.

Use four techniques:

### 1. Bootstrap endpoint

One initial API call can return common app data.

### 2. Local cache

Immediately render cached non-sensitive data while refreshing.

### 3. Aggregated detail endpoints

`GET /rides/:id` should include data required by ride detail screen:

```text
ride
driver public summary
vehicle summary
current user's booking state
```

Avoid 4-5 separate HTTP calls for one screen.

### 4. Realtime patches

After initial screen load, WebSocket updates only changed data.

---

## 31. Suggested Page/Data Mapping

Current report confirms 18 screens but does not enumerate every screen filename, so mapping here follows existing functional modules.

| UI / Feature | Initial REST | Realtime |
|---|---|---|
| App startup/home | `GET /bootstrap` | private user events |
| Login | `POST /auth/login` | connect socket after success |
| Register | `POST /auth/register` | none |
| Profile | `GET/PATCH /users/me` | verification/account update |
| Avatar picker | `PATCH /users/me/avatar` | optional profile update |
| Vehicle list | `GET /vehicles/me` | verification update |
| Vehicle create | `POST /vehicles` | verification update |
| Ride search | `GET /rides/search` | route subscription |
| Ride detail | `GET /rides/:id` | ride subscription |
| Create ride | `POST /rides` | event broadcast to searchers |
| My rides | `GET /rides/mine` | private + ride events |
| Ride requests | ride-request REST APIs | match/relevant updates |
| Booking list | `GET /bookings/mine` | booking events |
| Booking detail | `GET /bookings/:id` | booking + ride events |
| Active ride | `GET /rides/:id` | location + status events |
| Notifications | `GET /notifications` | notification.created |
| Reports | report REST APIs | admin/report status optional |
| Admin dashboard | `/admin/dashboard` | admin events |

---

## 32. Matching Service

Current weighted matching logic frontend/mock layer mein hai. Move authoritative matching logic to backend service.

Suggested inputs:

```text
route
start/end time
date
seats
budget
pickup distance
rating
reliability
```

Backend returns:

```json
{
  "ride": {},
  "matchScore": 92,
  "scoreBreakdown": {
    "route": 30,
    "time": 25,
    "pickup": 12,
    "budget": 10,
    "rating": 7,
    "reliability": 8
  }
}
```

Flutter only displays score; business formula backend owns karega.

---

## 33. Static / Seed Data

Testing fast banane ke liye deterministic seed script required hai.

Command:

```text
npm run db:seed
```

Suggested seed:

### Campuses

4 fake/test campuses.

### Users

```text
admin@campusride.test
student1@campusride.test
student2@campusride.test
driver1@campusride.test
driver2@campusride.test
```

### Vehicles

2-3 vehicles.

### Rides

At least:

- open ride with 3 seats
- open ride with 1 seat
- full ride
- started ride
- completed ride

### Ride requests

2-3 different time/budget combinations.

### Bookings

- requested
- accepted
- cancelled
- completed

### Notifications

Several read/unread examples.

### Reports

One open report for admin testing.

All seed data must be fake/non-production.

---

## 34. Swagger / OpenAPI

REST API should have OpenAPI documentation from the beginning.

Development route:

```text
http://localhost:3000/docs
```

Document:

- route
- method
- auth requirement
- body schema
- query params
- success response
- error codes

OpenAPI should match Zod/request schemas as closely as practical so API docs do not drift from implementation.

---

## 35. Security Baseline

### REST

- HTTPS in production
- Zod validation
- Argon2 password hashing
- JWT verification
- role checks
- resource ownership checks
- rate limiting
- Helmet/security headers
- request body size limits
- parameterized ORM/queries
- CORS restricted as relevant
- no secrets in source

### WebSocket

- authenticate socket
- authorize every subscription
- authorize every command
- location driver-only
- per-event rate limits
- max payload size
- heartbeat
- disconnect suspended users

### Data privacy

Never expose:

- password hashes
- refresh token hashes
- full private email unnecessarily
- emergency contact publicly
- internal admin notes

---

## 36. Logging

Structured logs should include:

```text
requestId
userId where available
method
route
status
duration
errorCode
```

WebSocket logs:

```text
connect
auth failure
subscribe/unsubscribe
disconnect
unexpected error
```

Do not log:

- passwords
- access tokens
- refresh tokens
- continuous GPS coordinates in production logs

---

## 37. Testing Plan

### Unit tests

- matching algorithm
- rating/reliability calculation
- auth/token service
- booking state machine
- ride state machine

### REST integration

- register/login
- ride CRUD
- search
- booking lifecycle
- admin permissions

### Concurrency

Critical test:

```text
Ride has 1 seat.
Two booking accepts run concurrently.
Exactly one succeeds.
Available seats never become negative.
```

### WebSocket

- unauthenticated socket rejected
- private user events not leaked
- route subscription receives ride.created
- booking acceptance reaches correct passenger
- location only reaches ride participants
- reconnect + resync works

### Flutter

Existing widget tests remain. Add repository/API mocked tests and offline-state tests.

---

## 38. Local Development

Recommended local ports:

```text
Backend HTTP/WS: 3000
PostgreSQL:      5432
Swagger:         3000/docs
```

Environment:

```text
DATABASE_URL=
JWT_ACCESS_SECRET=
JWT_REFRESH_SECRET=
PORT=3000
APP_ENV=development
```

Flutter config:

```text
API_BASE_URL=http://...
WS_BASE_URL=ws://...
```

Do not hardcode production URLs in Dart files.

Android emulator may need host-machine loopback address instead of literal device localhost; physical devices should use development machine LAN address.

---

## 39. Docker Local Setup

MVP Docker Compose needs only:

```text
postgres
backend
```

No storage container.
No Redis container.

Backend can also run directly through npm during development while PostgreSQL runs in Docker.

---

## 40. Production Deployment Later

Later deployment:

```text
Internet
   |
HTTPS / WSS
   |
Nginx or Caddy
   |
Node Backend
   |
PostgreSQL
```

Initial server can be one backend instance.

If future traffic requires multiple backend instances, WebSocket cross-instance event distribution can later introduce Redis pub/sub. Do not add it now.

---

## 41. Realtime Scalability Rule

MVP single process:

```text
REST + WebSocket server
   |
In-memory connection/subscription map
```

This is enough initially.

Scale later only when metrics justify it:

```text
Multiple API instances
   |
Redis pub/sub
   |
shared realtime events
```

Redis is therefore a scaling tool, not an MVP dependency.

---

## 42. What Stays in Flutter vs Backend

### Flutter owns

```text
UI
navigation
form state
rendering
local cache
WebSocket connection
GPS reading
static avatars
presentation formatting
```

### Backend owns

```text
auth truth
verification truth
ride truth
booking truth
seat availability
matching logic
permissions
rating eligibility
reliability
admin actions
notification records
```

Never trust client-calculated seat counts or permission flags.

---

## 43. MVP Build Phases

### Phase 1 — Backend Foundation

- create `/backend`
- TypeScript + Express
- env config
- error handling
- logging
- Zod validation
- PostgreSQL
- Prisma schema
- migrations
- Swagger
- seed script
- health endpoints

### Phase 2 — Auth + User

- register
- login
- refresh
- logout
- roles
- `/users/me`
- avatar key selection
- Flutter token storage

### Phase 3 — Campuses + Vehicles

- campus APIs
- vehicle CRUD
- admin verification flags
- local cache for campuses

### Phase 4 — Ride Offers + Search

- create ride
- edit/cancel
- ride search
- my rides
- backend matching
- indexes

### Phase 5 — Booking State Machine

- request
- accept
- reject
- cancel
- seat transaction
- check-in PIN
- start
- complete
- no-show

### Phase 6 — WebSocket Base

- authenticated WebSocket
- user channel
- route channel
- ride channel
- connection/reconnect
- realtime publisher abstraction

### Phase 7 — Realtime Ride/Booking Updates

- ride.created
- ride.updated
- seats.updated
- booking events
- notifications
- Flutter realtime UI patches

### Phase 8 — Live Location

- GPS permission
- location.update WebSocket command
- ride participant authorization
- 5-10 second adaptive updates
- latest location DB snapshot
- map UI later if not already present

### Phase 9 — Reports + Admin

- reports APIs
- user suspension
- verification
- admin dashboard summary
- audit log

### Phase 10 — Offline Hardening

- SQLite/Drift cache
- cached bootstrap
- offline banner
- socket reconnect
- REST resync
- safe retry/idempotency

### Phase 11 — Test & Deploy

- unit/integration tests
- concurrency tests
- WebSocket tests
- Docker
- staging/server deploy
- HTTPS/WSS

---

## 44. Definition of MVP Complete

MVP tab complete consider hoga jab:

- real users database mein persist hon
- login/password actually verify ho
- app restart par server data remain kare
- ride create ho aur doosre logged-in student ko realtime appear ho
- ride search real DB use kare
- booking request realtime driver tak pohanche
- accept/reject realtime passenger tak pohanche
- last seat double-book na ho
- ride status realtime update ho
- notifications persist + realtime push hon
- live driver location active ride participants ko show ho
- offline/disconnect app ko crash na kare
- reconnect par UI REST se resync ho
- admin verification/report flows real DB use karein
- Swagger available ho
- seed/reset commands available hon
- core tests pass hon

---

## 45. Final Decision Summary

```text
API                REST
Realtime           WebSocket
Database           PostgreSQL
Server             Custom Node/Express/TypeScript
Storage            None
Avatar              Static bundled PNG + avatar_key
Auth                Custom JWT/refresh token, provider abstraction
Flutter state       Existing Provider retained
Flutter REST        Dio
Flutter realtime    web_socket_channel
Offline cache       SQLite/Drift, read snapshot only
Location            WebSocket, ~5-10 sec adaptive
Docs                OpenAPI/Swagger
Deployment          Local first, server later
GraphQL             No
BaaS database       No
Redis               Not MVP
```

The most important implementation principle is:

> **REST commits authoritative state; WebSocket distributes committed changes immediately.**

Aur ephemeral realtime data, especially live location, directly WebSocket transport use kar sakta hai.

Is architecture se existing Flutter MVP ko rewrite kiye baghair real backend, persistence, realtime experience, offline resilience aur future scalability mil sakti hai.
