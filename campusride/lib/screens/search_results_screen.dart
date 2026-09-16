import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ride.dart';
import '../providers/app_state_provider.dart';
import '../widgets/common_widgets.dart';
import '../widgets/ride_card.dart';
import 'ride_detail_screen.dart';

class SearchResultsScreen extends StatefulWidget {
  final String fromCampusId;
  final String toCampusId;
  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final int seatsNeeded;

  const SearchResultsScreen({
    super.key,
    required this.fromCampusId,
    required this.toCampusId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.seatsNeeded,
  });

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  late Future<List<RideWithMatch>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<RideWithMatch>> _load() async {
    final state = context.read<AppStateProvider>();
    final raw = await state.searchRides(
      fromCampusId: widget.fromCampusId,
      toCampusId: widget.toCampusId,
      date: widget.date,
      maxDepartureHour: widget.endTime.hour,
      maxDepartureMinutes: widget.endTime.minute,
      seatsNeeded: widget.seatsNeeded,
    );
    final rides = <RideWithMatch>[];
    for (final item in raw) {
      final rideJson = item['ride'] as Map<String, dynamic>?;
      if (rideJson == null) continue;
      final driverJson = item['driver'] as Map<String, dynamic>?;
      final vehicleJson = item['vehicle'] as Map<String, dynamic>?;
      final match = ((item['match'] as Map<String, dynamic>?)?['matchScore'] as num?)?.toDouble() ?? 0;
      rides.add(RideWithMatch(Ride.fromApi(rideJson, driverJson: driverJson, vehicleJson: vehicleJson, givenMatch: match)));
    }
    return rides;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();
    final fromName = state.campusName(widget.fromCampusId);
    final toName = state.campusName(widget.toCampusId);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('$fromName → $toName', style: const TextStyle(fontSize: 15)),
            Text('${state.formatDate(widget.date)} | ${widget.startTime.format(context)} - ${widget.endTime.format(context)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
          ],
        ),
      ),
      body: FutureBuilder<List<RideWithMatch>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.cloud_off,
              title: 'Could not search rides',
              message: snapshot.error.toString(),
            );
          }
          final matches = snapshot.data ?? [];
          if (matches.isEmpty) {
            return const EmptyState(
              icon: Icons.search_off,
              title: 'No matching rides found',
              message: 'Try adjusting your time window or post a ride request instead.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _future = _load());
              await _future;
            },
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 12, bottom: 100),
              itemCount: matches.length,
              itemBuilder: (ctx, i) {
                final entry = matches[i];
                return RideCard(
                  ride: entry.ride,
                  matchScore: entry.ride.matchScore,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => RideDetailScreen(ride: entry.ride)),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class RideWithMatch {
  final Ride ride;
  RideWithMatch(this.ride);
}