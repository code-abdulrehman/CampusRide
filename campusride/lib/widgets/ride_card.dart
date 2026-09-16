import 'package:flutter/material.dart';
import '../models/ride.dart';
import 'common_widgets.dart';

class RideCard extends StatelessWidget {
  final Ride ride;
  final double? matchScore;
  final VoidCallback? onTap;

  const RideCard({super.key, required this.ride, this.matchScore, this.onTap});

  @override
  Widget build(BuildContext context) {
    final driver = ride.driver;
    final vehicle = ride.vehicle;
    final driverName = driver?.name ?? 'Driver';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Avatar(name: driverName, radius: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(driverName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(width: 6),
                            if (driver?.role == 'STUDENT' || driver?.isDriverVerified == true)
                              const Icon(Icons.verified, size: 14, color: Colors.green),
                          ],
                        ),
                        Text(
                          vehicle?.displayName ?? 'Vehicle',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (matchScore != null)
                    MatchScoreBadge(score: matchScore!)
                  else
                    StatusChip(label: ride.rideStatus.name.toUpperCase(), color: ride.isAvailable ? Colors.green : Colors.orange),
                ],
              ),
              const SizedBox(height: 12),
              _RouteTimeline(ride: ride),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.event_seat, size: 18, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text('${ride.availableSeats} seats',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                  const SizedBox(width: 16),
                  Icon(Icons.payments_outlined, size: 18, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text('Rs. ${ride.contributionPerSeat.toStringAsFixed(0)}',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                  const Spacer(),
                  if (driver != null)
                    StarRating(rating: driver.rating, size: 14)
                  else
                    const SizedBox(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteTimeline extends StatelessWidget {
  final Ride ride;

  const _RouteTimeline({required this.ride});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.green.shade700, shape: BoxShape.circle)),
            Container(width: 2, height: 22, color: Colors.grey.shade300),
            Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.red.shade600, shape: BoxShape.circle)),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(ride.origin, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(_formatTime(ride.departureTime), style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(ride.destination, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(_formatTime(ride.expectedArrivalTime), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final h = time.hour > 12 ? time.hour - 12 : time.hour;
    final suffix = time.hour >= 12 ? 'PM' : 'AM';
    return '${h == 0 ? 12 : h}:${time.minute.toString().padLeft(2, '0')} $suffix';
  }
}