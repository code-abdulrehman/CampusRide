import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/campus.dart';
import '../providers/app_state_provider.dart';
import '../widgets/common_widgets.dart';

class CreateRideScreen extends StatefulWidget {
  const CreateRideScreen({super.key});

  @override
  State<CreateRideScreen> createState() => _CreateRideScreenState();
}

class _CreateRideScreenState extends State<CreateRideScreen> {
  String _from = 'campus_a';
  String _to = 'main';
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _departure = const TimeOfDay(hour: 8, minute: 0);
  int _seats = 3;
  double _contribution = 200;
  String? _selectedVehicleId;
  String _notes = '';
  bool _recurring = false;
  bool _submitting = false;
  bool _campusDefaultsSet = false;
  final List<String> _recurringDays = [];
  final List<String> _conditions = ['University students only', 'No smoking'];

  void _ensureCampusDefaults(List<Campus> campuses) {
    if (_campusDefaultsSet || campuses.isEmpty) return;
    _campusDefaultsSet = true;
    _from = campuses.first.campusId;
    if (campuses.length > 1) {
      _to = campuses[1].campusId;
    }
  }

  static const _allConditions = [
    'University students only',
    'No smoking',
    'No food inside vehicle',
    'Pickup point flexible',
    'Small luggage allowed',
    'Large luggage allowed',
    'Return ride available',
  ];

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickDeparture() async {
    final picked = await showTimePicker(context: context, initialTime: _departure);
    if (picked != null) setState(() => _departure = picked);
  }

  Future<void> _publish() async {
    final state = context.read<AppStateProvider>();
    setState(() => _submitting = true);
    try {
      if (!state.canCreateRide()) {
        throw Exception('You must be a verified driver to offer rides.');
      }
      if (_selectedVehicleId == null) {
        throw Exception('Please select a vehicle.');
      }
      final vehicles = state.myVehicles;
      final vehicle = vehicles.where((v) => v.vehicleId == _selectedVehicleId).firstOrNull;
      if (vehicle == null || !vehicle.isVerified) {
        throw Exception('Vehicle must be verified before creating a ride.');
      }
      final departureDateTime = DateTime(_date.year, _date.month, _date.day, _departure.hour, _departure.minute);
      await state.createRide(
        originCampusId: _from,
        destinationCampusId: _to,
        departureDate: _date,
        departureTime: departureDateTime,
        vehicleId: _selectedVehicleId!,
        availableSeats: _seats,
        contributionPerSeat: _contribution,
        conditions: _conditions,
        additionalNotes: _notes.trim(),
        recurringRide: _recurring,
        recurringDays: _recurringDays,
      );
      if (!mounted) return;
      showAppSnack(context, 'Ride published!');
      Navigator.of(context).pop();
    } on Exception catch (e) {
      if (!mounted) return;
      showAppSnack(context, e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();
    final campuses = state.campuses;
    _ensureCampusDefaults(campuses);
    final vehicles = state.myVehicles;
    if (_selectedVehicleId == null && vehicles.isNotEmpty) {
      _selectedVehicleId = vehicles.first.vehicleId;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Offer a Ride')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('Route'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _dropdown('From', _from, (v) => setState(() => _from = v))),
              const SizedBox(width: 12),
              Expanded(child: _dropdown('To', _to, (v) => setState(() => _to = v))),
            ],
          ),
          const SizedBox(height: 20),
          _section('Schedule'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _infoTile(Icons.calendar_today, 'Date', _formatDate(_date), _pickDate),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _infoTile(Icons.schedule, 'Departure', _departure.format(context), _pickDeparture),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _section('Vehicle & Seats'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedVehicleId,
            decoration: const InputDecoration(labelText: 'Select Vehicle', prefixIcon: Icon(Icons.directions_car)),
            items: vehicles
                .map((v) => DropdownMenuItem(value: v.vehicleId, child: Text(v.displayName.isEmpty ? 'Car ${v.color}' : v.displayName)))
                .toList(),
            onChanged: (v) => setState(() => _selectedVehicleId = v),
          ),
          if (vehicles.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Register a vehicle in your profile first.',
                style: TextStyle(color: Colors.orange.shade700, fontSize: 13),
              ),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.event_seat, size: 20),
              const SizedBox(width: 12),
              const Text('Available Seats:'),
              Expanded(
                child: Slider(
                  value: _seats.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: '$_seats',
                  onChanged: (v) => setState(() => _seats = v.round()),
                ),
              ),
              Text('$_seats', style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.payments_outlined, size: 20),
              const SizedBox(width: 12),
              const Text('Contribution/seat: Rs.'),
              Expanded(
                child: Slider(
                  value: _contribution,
                  min: 50,
                  max: 500,
                  divisions: 45,
                  label: 'Rs. ${_contribution.round()}',
                  onChanged: (v) => setState(() => _contribution = v.roundToDouble()),
                ),
              ),
              Text('${_contribution.round()}', style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 20),
          _section('Ride Conditions'),
          Wrap(
            spacing: 8,
            runSpacing: 0,
            children: _allConditions.map((c) {
              final selected = _conditions.contains(c);
              return FilterChip(
                label: Text(c),
                selected: selected,
                onSelected: (sel) {
                  setState(() {
                    if (sel) {
                      _conditions.add(c);
                    } else {
                      _conditions.remove(c);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Recurring Ride', style: TextStyle(fontWeight: FontWeight.w600)),
            value: _recurring,
            onChanged: (v) => setState(() => _recurring = v),
            subtitle: _recurring
                ? Wrap(
                    spacing: 6,
                    children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri']
                        .map((d) => ChoiceChip(
                              label: Text(d),
                              selected: _recurringDays.contains(d),
                              onSelected: (sel) {
                                setState(() {
                                  if (sel) {
                                    _recurringDays.add(d);
                                  } else {
                                    _recurringDays.remove(d);
                                  }
                                });
                              },
                            ))
                        .toList())
                : null,
          ),
          const SizedBox(height: 14),
          TextField(
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Additional Notes (optional)',
              hintText: 'e.g. I will wait 5 minutes max at pickup.',
            ),
            onChanged: (v) => _notes = v,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _submitting ? null : _publish,
            icon: _submitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.publish),
            label: const Text('Publish Ride'),
          ),
        ],
      ),
    );
  }

  Widget _section(String title) => Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15));

  Widget _dropdown(String label, String value, ValueChanged<String> onChanged) {
    final campuses = context.watch<AppStateProvider>().campuses;
    if (campuses.isEmpty) {
      return const SizedBox(height: 56, child: Center(child: Text('Loading campuses…')));
    }
    return DropdownButtonFormField<String>(
      initialValue: campuses.any((c) => c.campusId == value) ? value : campuses.first.campusId,
      decoration: InputDecoration(labelText: label),
      items: campuses.map((c) => DropdownMenuItem(value: c.campusId, child: Text(c.campusName))).toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  Widget _infoTile(IconData icon, String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, size: 16, color: Colors.grey.shade600), const SizedBox(width: 6), Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))]),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]}';
  }
}