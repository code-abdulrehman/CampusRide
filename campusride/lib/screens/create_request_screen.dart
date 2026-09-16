import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../widgets/common_widgets.dart';

class CreateRequestScreen extends StatefulWidget {
  const CreateRequestScreen({super.key});

  @override
  State<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<CreateRequestScreen> {
  String _from = 'campus_a';
  String _to = 'main';
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  int _startHour = 7;
  int _startMinute = 45;
  int _latestHour = 8;
  int _latestMinute = 30;
  int _seats = 1;
  double _budget = 300;
  bool _submitting = false;

  String _timeString(int h, int m) {
    final hour12 = h > 12 ? h - 12 : h;
    final suffix = h >= 12 ? 'PM' : 'AM';
    return '${hour12 == 0 ? 12 : hour12}:${m.toString().padLeft(2, '0')} $suffix';
  }

  Future<void> _submit() async {
    final state = context.read<AppStateProvider>();
    setState(() => _submitting = true);
    try {
      await state.createRideRequest(
        originCampusId: _from,
        destinationCampusId: _to,
        preferredDate: _date,
        startHour: _startHour,
        startMinute: _startMinute,
        latestHour: _latestHour,
        latestMinute: _latestMinute,
        requiredArrivalTime: DateTime(_date.year, _date.month, _date.day, 9, 0),
        requiredSeats: _seats,
        maxBudget: _budget,
      );
      if (!mounted) return;
      showAppSnack(context, 'Ride request posted! Matching drivers will be notified.');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final campuses = context.watch<AppStateProvider>().campuses;
    if (_from == 'campus_a' && campuses.isNotEmpty) {
      _from = campuses.first.campusId;
    }
    if (_to == 'main' && campuses.length > 1) {
      _to = campuses[1].campusId;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('I Need a Ride')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Post your ride requirement and matching drivers will be notified.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _campusDropdown('From', _from, (v) => setState(() => _from = v))),
              const SizedBox(width: 12),
              Expanded(child: _campusDropdown('To', _to, (v) => setState(() => _to = v))),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _field(Icons.calendar_today, 'Date', _formatDate(_date), _pickDate),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field(Icons.event_seat, 'Seats', '$_seats', _pickSeats),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Departure: ', style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              _timePicker('Earliest', _startHour, _startMinute, (h, m) => setState(() { _startHour = h; _startMinute = m; })),
              const Text(' — ', style: TextStyle(fontWeight: FontWeight.w700)),
              _timePicker('Latest', _latestHour, _latestMinute, (h, m) => setState(() { _latestHour = h; _latestMinute = m; })),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.payments_outlined),
              const SizedBox(width: 12),
              Text('Max Budget: Rs.${_budget.round()}', style: const TextStyle(fontWeight: FontWeight.w600)),
              Expanded(
                child: Slider(
                  value: _budget,
                  min: 50,
                  max: 500,
                  divisions: 45,
                  onChanged: (v) => setState(() => _budget = v.roundToDouble()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send),
            label: const Text('Post Ride Request'),
          ),
        ],
      ),
    );
  }

  Widget _campusDropdown(String label, String value, ValueChanged<String> onChanged) {
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

  Widget _field(IconData icon, String label, String value, VoidCallback onTap) {
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickSeats() async {
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Seats needed'),
        children: [1, 2, 3].map((s) => SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, s),
          child: Text('$s seat${s > 1 ? 's' : ''}'),
        )).toList(),
      ),
    );
    if (picked != null) setState(() => _seats = picked);
  }

  Widget _timePicker(String label, int h, int m, void Function(int h, int m) onChange) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: h, minute: m));
        if (picked != null) onChange(picked.hour, picked.minute);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(_timeString(h, m), style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1B6B4A))),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]}';
  }
}