import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ride.dart';
import '../providers/app_state_provider.dart';
import '../widgets/common_widgets.dart';

class RatingScreen extends StatefulWidget {
  final Ride ride;

  const RatingScreen({super.key, required this.ride});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  int _overall = 0;
  int _punctuality = 0;
  int _behaviour = 0;
  int _communication = 0;
  final _commentController = TextEditingController();
  bool _rated = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submit() {
    final state = context.read<AppStateProvider>();
    final driverId = widget.ride.driver?.userId ?? widget.ride.driverId;
    state.submitRating(
      rideId: widget.ride.rideId,
      rateeId: driverId,
      overallRating: _overall.toDouble(),
      punctuality: _punctuality.toDouble(),
      behaviour: _behaviour.toDouble(),
      communication: _communication.toDouble(),
      comment: _commentController.text.trim(),
    );
    setState(() => _rated = true);
    showAppSnack(context, 'Thank you for your feedback!');
  }

  @override
  Widget build(BuildContext context) {
    final ride = widget.ride;
    final driver = ride.driver;
    final state = context.watch<AppStateProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Rate Your Ride')),
      body: _rated || state.hasRated(ride.rideId)
          ? const EmptyState(
              icon: Icons.thumb_up_alt,
              title: 'Rating submitted',
              message: 'Thanks for helping keep the CampusRide community reliable.',
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Column(
                    children: [
                      Avatar(name: driver?.name ?? '?', radius: 30),
                      const SizedBox(height: 8),
                      Text(driver?.name ?? 'Driver', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                      Text('${ride.origin} → ${ride.destination}', style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _rateRow('Overall Rating', _overall, (v) => setState(() => _overall = v)),
                        const Divider(),
                        _rateRow('Punctuality', _punctuality, (v) => setState(() => _punctuality = v)),
                        const Divider(),
                        _rateRow('Behaviour', _behaviour, (v) => setState(() => _behaviour = v)),
                        const Divider(),
                        _rateRow('Communication', _communication, (v) => setState(() => _communication = v)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _commentController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Comment (optional)', hintText: 'How was your trip?'),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _overall == 0 ? null : _submit,
                  icon: const Icon(Icons.send),
                  label: const Text('Submit Rating'),
                ),
              ],
            ),
    );
  }

  Widget _rateRow(String label, int value, ValueChanged<int> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        Row(
          children: List.generate(5, (i) {
            final starVal = i + 1;
            return IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              iconSize: 26,
              onPressed: () => onChanged(starVal),
              icon: Icon(
                starVal <= value ? Icons.star : Icons.star_border,
                color: Colors.amber,
              ),
            );
          }),
        ),
      ],
    );
  }
}