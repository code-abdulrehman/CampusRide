import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/enums.dart';
import '../models/booking.dart';
import '../models/ride.dart';
import '../providers/app_state_provider.dart';
import '../widgets/common_widgets.dart';
import '../widgets/ride_card.dart';
import 'ride_detail_screen.dart';
import 'rating_screen.dart';

class MyRidesScreen extends StatefulWidget {
  const MyRidesScreen({super.key});

  @override
  State<MyRidesScreen> createState() => _MyRidesScreenState();
}

class _MyRidesScreenState extends State<MyRidesScreen> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final state = context.read<AppStateProvider>();
    setState(() => _loading = true);
    await Future.wait([
      state.loadMyRides(),
      state.loadMyBookings(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();
    final user = state.currentUser;
    if (user == null) return const SizedBox();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Rides'),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loading ? null : _refresh,
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.directions_car, size: 18), text: 'Driving'),
              Tab(icon: Icon(Icons.person, size: 18), text: 'Passenger'),
            ],
          ),
        ),
        body: TabBarView(
          children: [_driverView(state), _passengerView(state)],
        ),
      ),
    );
  }

  // --- Driver view: rides I created + pending requests need management ---
  Widget _driverView(AppStateProvider state) {
    final myRides = state.myRides;

    if (myRides.isEmpty) {
      return _loading
          ? const Center(child: CircularProgressIndicator())
          : const EmptyState(
              icon: Icons.directions_car_outlined,
              title: 'No rides posted yet',
              message: 'Offer a ride from the home screen to fill your empty seats.',
            );
    }

    return FutureBuilder<Map<Ride, List<Booking>>>(
      future: _fetchPendingRequests(state, myRides),
      builder: (context, snapshot) {
        final pendingRequests = snapshot.data ?? {};
        return ListView(
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            if (pendingRequests.isNotEmpty)
              Card(
                margin: const EdgeInsets.all(16),
                color: Colors.orange.shade50,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.notifications_active, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Pending seat requests', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...pendingRequests.entries.map((entry) => _requestTile(state, entry.key, entry.value)),
                    ],
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'All seat requests handled 👍',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            const SizedBox(height: 4),
            ...myRides.map((ride) => RideCard(
                  ride: ride,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RideDetailScreen(ride: ride))),
                )),
          ],
        );
      },
    );
  }

  Future<Map<Ride, List<Booking>>> _fetchPendingRequests(
      AppStateProvider state, List<Ride> rides) async {
    final map = <Ride, List<Booking>>{};
    for (final ride in rides) {
      final raw = await state.getBookingsByRide(ride.rideId);
      final bookings = raw
          .map((b) => Booking.fromApi(b))
          .where((b) => b.status == BookingStatus.requested)
          .toList();
      if (bookings.isNotEmpty) map[ride] = bookings;
    }
    return map;
  }

  Widget _requestTile(AppStateProvider state, Ride ride, List<Booking> bookings) {
    return Column(
      children: bookings.map((b) {
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Avatar(name: b.passengerName ?? '?', radius: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.passengerName ?? 'Passenger', style: const TextStyle(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('${ride.origin} → ${ride.destination} • ${b.seatsBooked} seat', style: TextStyle(fontSize: 12, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Reject',
                visualDensity: VisualDensity.compact,
                onPressed: () => state.rejectBooking(b),
                icon: const Icon(Icons.close, color: Colors.red),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                onPressed: () => state.acceptBooking(b),
                child: const Text('Accept'),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // --- Passenger view: my bookings ---
  Widget _passengerView(AppStateProvider state) {
    final myBookings = state.myBookings;
    if (myBookings.isEmpty) {
      return _loading
          ? const Center(child: CircularProgressIndicator())
          : const EmptyState(
              icon: Icons.event_seat,
              title: 'No bookings yet',
              message: 'Search for rides and request a seat.',
            );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        ...myBookings.map((b) => _bookingTile(state, b)),
      ],
    );
  }

  Widget _bookingTile(AppStateProvider state, Booking b) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        isThreeLine: true,
        leading: Avatar(name: b.driverName ?? 'D', radius: 22),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${b.rideOrigin} → ${b.rideDestination}',
                style: const TextStyle(fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _statusBadge(b.status),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${b.driverName ?? 'Driver'} • ${b.rideDepartureAt != null ? state.formatTime(b.rideDepartureAt!) : ''} • ${b.seatsBooked} seat'),
            const SizedBox(height: 4),
            Text(
              b.status == BookingStatus.accepted
                  ? 'Ride PIN: ${b.ridePin}'
                  : 'Contribution: Rs. ${b.amountPaid.toStringAsFixed(0)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        trailing: switch (b.status) {
          BookingStatus.completed => IconButton(
              icon: const Icon(Icons.star, color: Colors.amber),
              onPressed: () {
                final ride = state.myRides
                    .where((r) => r.rideId == b.rideId)
                    .firstOrNull;
                if (ride != null) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => RatingScreen(ride: ride)));
                }
              },
            ),
          BookingStatus.requested || BookingStatus.accepted || BookingStatus.checkedIn => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (b.status != BookingStatus.checkedIn)
                  IconButton(
                    icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                    onPressed: () {
                      state.cancelBooking(b);
                      showAppSnack(context, 'Booking cancelled.');
                    },
                  )
                else
                  const SizedBox.shrink(),
                Text('Cancel', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
              ],
            ),
          _ => SizedBox(
              width: 60,
              child: StatusChip(label: b.status.name, color: Colors.grey),
            ),
        },
      ),
    );
  }

  Widget _statusBadge(BookingStatus status) {
    final (label, color) = switch (status) {
      BookingStatus.requested => ('Requested', Colors.orange),
      BookingStatus.accepted => ('Confirmed', Colors.green),
      BookingStatus.rejected => ('Rejected', Colors.red),
      BookingStatus.cancelled => ('Cancelled', Colors.grey),
      BookingStatus.checkedIn => ('Checked In', Colors.blue),
      BookingStatus.rideStarted => ('In Ride', Colors.purple),
      BookingStatus.completed => ('Completed', Colors.teal),
      BookingStatus.noShow => ('No Show', Colors.red),
    };
    return StatusChip(label: label, color: color);
  }
}