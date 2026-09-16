import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ride.dart';
import '../models/booking.dart';
import '../models/enums.dart';
import '../models/user.dart';
import '../providers/app_state_provider.dart';
import '../services/api_client.dart';
import '../widgets/common_widgets.dart';
import 'rating_screen.dart';
import 'sos_screen.dart';

class RideDetailScreen extends StatefulWidget {
  final Ride ride;

  const RideDetailScreen({super.key, required this.ride});

  @override
  State<RideDetailScreen> createState() => _RideDetailScreenState();
}

class _RideDetailScreenState extends State<RideDetailScreen> {
  late Ride _ride;
  CampusUser? _driver;
  dynamic _vehicle;
  List<Map<String, dynamic>> _bookings = [];
  Booking? _myBooking;
  bool _isDriver = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ride = widget.ride;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final state = context.read<AppStateProvider>();
      final data = await state.repository.getRideDetail(_ride.rideId);
      if (!mounted) return;
      setState(() {
        final rideJson = data['ride'] as Map<String, dynamic>?;
        if (rideJson != null) {
          _ride = Ride.fromApi(
            rideJson,
            driverJson: data['driver'] as Map<String, dynamic>?,
            vehicleJson: data['vehicle'] as Map<String, dynamic>?,
          );
        }
        final driverJson = data['driver'] as Map<String, dynamic>?;
        _driver = driverJson != null ? CampusUser.fromApi(driverJson) : _ride.driver;
        if (data['vehicle'] != null) _vehicle = data['vehicle'];
        _isDriver = (data['isDriver'] as bool? ?? false) || _ride.driverId == state.currentUser?.userId;
        final myBookingRaw = data['myBooking'] as Map<String, dynamic>?;
        _myBooking = myBookingRaw != null ? Booking.fromApi(myBookingRaw) : null;
        _bookings = (data['bookings'] as List<dynamic>? ?? []).map((b) => (b as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();
    final currentUser = state.currentUser;
    final isDriver = _isDriver;

    final confirmedBookings = _bookings
        .map((b) => Booking.fromApi(b))
        .where((b) =>
            b.status == BookingStatus.accepted ||
            b.status == BookingStatus.checkedIn ||
            b.status == BookingStatus.rideStarted)
        .toList();

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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(icon: Icons.cloud_off, title: 'Ride unavailable', message: _error!)
              : ListView(
                  padding: const EdgeInsets.only(bottom: 100),
                  children: [
                    if (_driver != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Avatar(name: _driver!.name, radius: 28),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Flexible(
                                      child: Text(_driver!.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ),
                                    const SizedBox(width: 6),
                                    VerifiedBadge(verified: _driver!.isStudentVerified),
                                  ]),
                                  const SizedBox(height: 2),
                                  Row(children: [
                                    StarRating(rating: _driver!.rating, size: 14),
                                    Text('  •  ${_driver!.completedRides} rides  •  ${_driver!.reliabilityScore.toStringAsFixed(0)}% reliable', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
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
                            _routeInfo(Icons.trip_origin, 'Departure', '${state.formatTime(_ride.departureTime)}  •  ${state.formatDate(_ride.departureDate)}'),
                            _routeInfo(Icons.location_on, 'Destination', state.formatTime(_ride.expectedArrivalTime)),
                            _routeInfo(Icons.event_seat, 'Seats', '${_ride.availableSeats} available'),
                            _routeInfo(Icons.payments_outlined, 'Contribution', 'Rs. ${_ride.contributionPerSeat.toStringAsFixed(0)} per seat'),
                            if ((_ride.ridePin ?? '').isNotEmpty)
                              _routeInfo(Icons.lock_outline, 'Ride PIN', isDriver ? _ride.ridePin! : 'Confirmed passengers only'),
                          ],
                        ),
                      ),
                    ),
                    if (_vehicle != null && (_vehicle as Map<String, dynamic>)['id'] != null)
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
                                Flexible(
                                  child: Text(
                                    '${(_vehicle as Map<String, dynamic>)['company']} ${(_vehicle as Map<String, dynamic>)['model']} • ${(_vehicle as Map<String, dynamic>)['color']} • ${(_vehicle as Map<String, dynamic>)['year']}',
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ]),
                            ],
                          ),
                        ),
                      ),
                    if (_ride.conditions.isNotEmpty)
                      Card(
                        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Ride Conditions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                              const SizedBox(height: 8),
                              ..._ride.conditions.map((c) => Padding(
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
                    if (_ride.additionalNotes.isNotEmpty)
                      Card(
                        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Driver Note', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                              const SizedBox(height: 6),
                              Text(_ride.additionalNotes, style: TextStyle(color: Colors.grey.shade700)),
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
                                  Text('Earning: Rs. ${confirmedBookings.fold<int>(0, (p, b) => p + b.seatsBooked * _ride.contributionPerSeat.toInt())}', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w700)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ...confirmedBookings.map((b) {
                                final pName = b.passengerName ?? 'Passenger';
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Avatar(name: pName, radius: 18),
                                  title: Text(pName),
                                  subtitle: Text('${b.seatsBooked} seat • Checked In: ${b.status == BookingStatus.checkedIn || b.status == BookingStatus.rideStarted}'),
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
              : _passengerActions(context, state),
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
    if (_ride.rideStatus == RideStatus.completed) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade300),
        child: const Text('Ride Completed', style: TextStyle(color: Colors.black54)),
      );
    }
    if (_ride.rideStatus == RideStatus.started) {
      return FilledButton(
        style: FilledButton.styleFrom(backgroundColor: Colors.orange),
        onPressed: () async {
          try {
            final updated = await state.completeRide(_ride);
            setState(() => _ride = updated);
            showAppSnack(context, 'Ride completed!');
          } catch (e) {
            showAppSnack(context, e.toString(), error: true);
          }
        },
        child: const Text('Complete Ride'),
      );
    }
    return FilledButton.icon(
      onPressed: () async {
        try {
          final updated = await state.startRide(_ride);
          setState(() => _ride = updated);
          showAppSnack(context, 'Ride started! Stay safe.');
        } catch (e) {
          showAppSnack(context, e.toString(), error: true);
        }
      },
      icon: const Icon(Icons.play_arrow),
      label: const Text('Start Ride'),
    );
  }

  Widget _passengerActions(BuildContext context, AppStateProvider state) {
    final myBooking = _myBooking;
    if (myBooking != null) {
      final status = myBooking.status;
      if (status == BookingStatus.completed) {
        return FilledButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RatingScreen(ride: _ride))),
          icon: const Icon(Icons.star),
          label: const Text('Rate Driver'),
        );
      }
      if (status == BookingStatus.accepted || status == BookingStatus.checkedIn) {
        return Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _showCheckInDialog(context, state, myBooking),
              child: const Text('Check In (PIN)'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () async {
                try {
                  await state.cancelBooking(myBooking);
                  showAppSnack(context, 'Booking cancelled.');
                  _load();
                } catch (e) {
                  showAppSnack(context, e.toString(), error: true);
                }
              },
              child: const Text('Cancel'),
            ),
          ),
        ]);
      }
      return StatusChip(label: status.name, color: Colors.grey);
    }
    return FilledButton.icon(
      onPressed: _ride.isAvailable
          ? () {
              if (!(state.currentUser?.isStudentVerified ?? false)) {
                showAppSnack(context, 'Please verify your student account in your profile first.', error: true);
                return;
              }
              _showBookingDialog(context, state);
            }
          : null,
      icon: const Icon(Icons.request_quote),
      label: Text(_ride.availableSeats > 0 ? 'Request Seat (${_ride.availableSeats} left)' : 'Full'),
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
              Text('Contribution: Rs. ${(_ride.contributionPerSeat * seats).toStringAsFixed(0)}'),
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
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  final booking = await state.requestSeat(_ride, seats: seats);
                  setState(() => _myBooking = booking);
                  showAppSnack(context, 'Seat request sent! Awaiting driver confirmation.');
                } catch (e) {
                  showAppSnack(context, e.toString(), error: true);
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCheckInDialog(BuildContext context, AppStateProvider state, Booking myBooking) {
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
            onPressed: () async {
              try {
                final updated = await state.checkIn(myBooking, pinController.text.trim());
                if (!mounted) return;
                Navigator.pop(ctx);
                setState(() => _myBooking = updated);
                showAppSnack(context, 'Check-in successful!');
              } catch (e) {
                if (!mounted) return;
                Navigator.pop(ctx);
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