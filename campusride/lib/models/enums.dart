enum UserVerificationStatus { none, studentPending, studentVerified, driverPending, driverVerified }

enum VehicleStatus { none, pending, verified, rejected, suspended }

enum RideStatus { open, full, started, completed, cancelled, expired }

enum BookingStatus { requested, accepted, rejected, cancelled, checkedIn, rideStarted, completed, noShow }

enum ReportReason { dangerousDriving, harassment, fakeDetails, noShow, excessiveCharging, misbehavior, wrongPickup, spam, other }

enum ReportStatus { pending, reviewed, warning, temporarySuspension, permanentBan }

enum AccountStatus { active, suspended }

enum RideType { interCampus, homeToCampus, other }
