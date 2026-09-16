import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ride.dart';
import '../models/booking.dart';
import '../models/enums.dart';
import '../providers/app_state_provider.dart';
import '../widgets/common_widgets.dart';
import 'rating_screen.dart';
import 'sos_screen.dart';

class RideDetailScreen extends StatelessWidget {
  final Ride ride;

  const RideDetailScreen({super.key, required this.ride});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();
    final repo = state.repository;
    final driver = repo.getUserById(ride.driverId);
    final vehicle = repo.getVehicleById(ride.vehicleId);
    final currentUser = state.currentUser;
    final myBookings = repo.getBookingsByRide(ride.rideId);
    final myBooking = currentUser != null
        ? myBookings.firstWhere(
            (b) => b.passengerId == currentUser.userId,
            orElse: () => Booking(bookingId: '', rideId: '', passengerId: '', driverId: ''),
          )
        : null;
    final hasMyBooking = myBooking?.bookingId.isNotEmpty == true;
    final isDriver = currentUser?.userId == ride.driverId;
    final totalIncome = myBookings.where((b) => b.status != BookingStatus.cancelled).fold(0.0, (p, b) => p + b.amountPaid);
    final confirmedBookings = myBookings.where((b) => b.status == BookingStatus.accepted || b.status == BookingStatus.checkedIn || b.status == BookingStatus.rideStarted).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride Details'),
        actions: [
          if (!isDriver && currentUser != null)
            IconButton(
              icon: const Icon(Icons.sos, color: Colors.red),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SosScreen())),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          if (driver != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Avatar(name: driver.name, radius: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(driver.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                          const SizedBox(width: 6),
                          VerifiedBadge(verified: driver.isStudentVerified),
                        ]),
                        const SizedBox(height: 2),
                        Row(children: [
                          StarRating(rating: driver.rating, size: 14),
                          Text('  •  ${driver.completedRides} rides  •  ${driver.reliabilityScore.toStringAsFixed(0)}% reliable', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Route & Schedule', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 12),
                  _routeInfo(Icons.trip_origin, 'Departure', '${state.formatTime(ride.departureTime)}  •  ${state.formatDate(ride.departureDate)}'),
                  _routeInfo(Icons.location_on, 'Destination', state.formatTime(ride.expectedArrivalTime)),
                  _routeInfo(Icons.event_seat, 'Seats', '${ride.availableSeats} available'),
                  _routeInfo(Icons.payments_outlined, 'Contribution', 'Rs. ${ride.contributionPerSeat.toStringAsFixed(0)} per seat'),
                  if (ride.ridePin.isNotEmpty)
                    _routeInfo(Icons.lock_outline, 'Ride PIN', isDriver ? ride.ridePin : 'Confirmed passengers only'),
                ],
              ),
            ),
          ),
          if (vehicle != null && vehicle.displayName.isNotEmpty)
            Card(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Vehicle', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(Icons.directions_car, color: Colors.grey.shade600),
                      const SizedBox(width: 10),
                      Text('${vehicle.displayName} • ${vehicle.color} • ${vehicle.modelYear} • ${vehicle.registrationNumber}',
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                      const Spacer(),
                      VerifiedBadge(verified: vehicle.isVerified),
                    ]),
                  ],
                ),
              ),
            ),
          if (ride.conditions.isNotEmpty)
            Card(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ride Conditions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 8),
                    ...ride.conditions.map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(children: [
                            const Icon(Icons.check_circle, size: 16, color: Colors.green),
                            const SizedBox(width: 8),
                            Text(c, style: const TextStyle(fontSize: 14)),
                          ]),
                        )),
                  ],
                ),
              ),
            ),
          if (ride.additionalNotes.isNotEmpty)
            Card(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Driver Note', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 6),
                    Text(ride.additionalNotes, style: TextStyle(color: Colors.grey.shade700)),
                  ],
                ),
              ),
            ),
          if (isDriver && confirmedBookings.isNotEmpty)
            Card(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Passengers', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        Text('Earning: Rs. ${totalIncome.toStringAsFixed(0)}', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...confirmedBookings.map((b) {
                      final passenger = repo.getUserById(b.passengerId);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Avatar(name: passenger?.name ?? '?', radius: 18),
                        title: Text(passenger?.name ?? 'Passenger'),
                        subtitle: Text('${b.seatsBooked} seat • ${b.pickupPoint}'),
                        trailing: _bookingStatusBadge(b.status),
                      );
                    }),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: isDriver
              ? _driverActions(context, state)
              : _passengerActions(context, state, myBooking, hasMyBooking),
        ),
      ),
    );
  }

  Widget _routeInfo(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.green.shade700),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.black54)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _bookingStatusBadge(BookingStatus status) {
    final (label, color) = switch (status) {
      BookingStatus.requested => ('Requested', Colors.orange),
      BookingStatus.accepted => ('Confirmed', Colors.green),
      BookingStatus.rejected => ('Rejected', Colors.red),
      BookingStatus.cancelled => ('Cancelled', Colors.grey),
      BookingStatus.checkedIn => ('Checked In', Colors.blue),
      BookingStatus.rideStarted => ('In Ride', Colors.purple),
      BookingStatus.completed => ('Completed', Colors.green),
      BookingStatus.noShow => ('No Show', Colors.red),
    };
    return StatusChip(label: label, color: color);
  }

  Widget _driverActions(BuildContext context, AppStateProvider state) {
    if (ride.rideStatus == RideStatus.completed) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade300),
        child: const Text('Ride Completed', style: TextStyle(color: Colors.black54)),
      );
    }
    if (ride.rideStatus == RideStatus.started) {
      return FilledButton(
        style: FilledButton.styleFrom(backgroundColor: Colors.orange),
        onPressed: () {
          state.completeRide(ride);
          showAppSnack(context, 'Ride completed! Rate your passengers.');
        },
        child: const Text('Complete Ride'),
      );
    }
    return FilledButton.icon(
      onPressed: () {
        state.startRide(ride);
        showAppSnack(context, 'Ride started! Stay safe.');
      },
      icon: const Icon(Icons.play_arrow),
      label: const Text('Start Ride'),
    );
  }

  Widget _passengerActions(BuildContext context, AppStateProvider state, Booking? myBooking, bool hasMyBooking) {
    if (hasMyBooking) {
      final status = myBooking!.status;
      if (status == BookingStatus.completed) {
        return FilledButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RatingScreen(ride: ride))),
          icon: const Icon(Icons.star),
          label: const Text('Rate Driver'),
        );
      }
      if (status == BookingStatus.accepted || status == BookingStatus.checkedIn) {
        return Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _showCheckInDialog(context, state),
              child: const Text('Check In (PIN)'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () {
                state.cancelBooking(myBooking);
                showAppSnack(context, 'Booking cancelled.');
              },
              child: const Text('Cancel'),
            ),
          ),
        ]);
      }
      return StatusChip(label: status.name, color: Colors.grey);
    }
    return FilledButton.icon(
      onPressed: ride.isAvailable
          ? () {
              if (!state.currentUser!.isStudentVerified) {
                showAppSnack(context, 'Please verify your student account in your profile first.', error: true);
                return;
              }
              _showBookingDialog(context, state);
            }
          : null,
      icon: const Icon(Icons.request_quote),
      label: Text(ride.availableSeats > 0 ? 'Request Seat (${ride.availableSeats} left)' : 'Full'),
    );
  }

  void _showBookingDialog(BuildContext context, AppStateProvider state) {
    int seats = 1;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Confirm Booking'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Contribution: Rs. ${(ride.contributionPerSeat * seats).toStringAsFixed(0)}'),
              const SizedBox(height: 10),
              const Text('Seats:', style: TextStyle(fontWeight: FontWeight.w600)),
              SegmentedButton<int>(
                segments: [1, 2, 3].map((n) => ButtonSegment(value: n, label: Text('$n'))).toList(),
                selected: {seats},
                onSelectionChanged: (v) => setDialogState(() => seats = v.first),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                state.requestSeat(ride, seats: seats);
                showAppSnack(context, 'Seat request sent! Awaiting driver confirmation.');
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCheckInDialog(BuildContext context, AppStateProvider state) {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ride Check-In'),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          maxLength: 4,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, letterSpacing: 8),
          decoration: const InputDecoration(
            hintText: '----',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final myBooking = state.repository.getBookingsByRide(ride.rideId).firstWhere(
                  (b) => b.passengerId == state.currentUser?.userId && b.status == BookingStatus.accepted);
              try {
                state.checkIn(myBooking, pinController.text.trim());
                Navigator.pop(ctx);
                showAppSnack(context, 'Check-in successful!');
              } catch (e) {
                showAppSnack(context, e.toString(), error: true);
              }
            },
            child: const Text('Verify PIN'),
          ),
        ],
      ),
    );
  }
}