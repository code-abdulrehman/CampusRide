import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/campus.dart';
import '../providers/app_state_provider.dart';
import '../widgets/common_widgets.dart';
import '../widgets/ride_card.dart';
import 'ride_detail_screen.dart';

class SearchResultsScreen extends StatelessWidget {
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

  String _campusName(String id) => Campus.sampleCampuses.firstWhere((c) => c.campusId == id, orElse: () => const Campus(campusId: '', campusName: 'Unknown', address: '')).campusName;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();
    final matches = state.repository.findMatchingRides(
      fromCampusId: fromCampusId,
      toCampusId: toCampusId,
      date: date,
      startTime: startTime,
      endTime: endTime,
      budget: 300,
      seatsNeeded: seatsNeeded,
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('${_campusName(fromCampusId)} → ${_campusName(toCampusId)}', style: const TextStyle(fontSize: 15)),
            Text('${state.formatDate(date)} | ${startTime.format(context)} - ${endTime.format(context)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
          ],
        ),
      ),
      body: matches.isEmpty
          ? const EmptyState(
              icon: Icons.search_off,
              title: 'No matching rides found',
              message: 'Try adjusting your time window or post a ride request instead.',
            )
          : ListView.builder(
              padding: const EdgeInsets.only(top: 12, bottom: 100),
              itemCount: matches.length,
              itemBuilder: (ctx, i) {
                final entry = matches[i];
                return RideCard(
                  ride: entry.key,
                  matchScore: entry.value,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => RideDetailScreen(ride: entry.key)),
                  ),
                );
              },
            ),
    );
  }
}