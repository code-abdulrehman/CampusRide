import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/campus.dart';
import '../providers/app_state_provider.dart';
import 'search_results_screen.dart';
import 'create_request_screen.dart';
import 'admin_dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _from = 'campus_a';
  String _to = 'main';
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _start = const TimeOfDay(hour: 7, minute: 30);
  TimeOfDay _end = const TimeOfDay(hour: 8, minute: 30);
  int _seats = 1;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final initial = isStart ? _start : _end;
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() {
        if (isStart) {
          _start = picked;
        } else {
          _end = picked;
        }
      });
    }
  }

  void _findRides() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SearchResultsScreen(
        fromCampusId: _from,
        toCampusId: _to,
        date: _date,
        startTime: _start,
        endTime: _end,
        seatsNeeded: _seats,
      ),
    ));
  }

  void _postRequest() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateRequestScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final greetings = _greeting();
    final userName = context.watch<AppStateProvider>().currentUser?.name ?? 'Student';
    return Scaffold(
      appBar: AppBar(
        title: const Text('CampusRide'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 90),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$greetings, $userName 👋',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Find a campus ride or share your seats.',
                    style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Search Rides', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.trip_origin, color: Colors.green),
                      const SizedBox(width: 8),
                      const Text('From', style: TextStyle(fontSize: 12, color: Colors.black54)),
                      const SizedBox(width: 8),
                      Expanded(child: _campusDropdown(isFrom: true)),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 9),
                    child: SizedBox(
                      height: 24,
                      child: VerticalDivider(width: 2, color: Colors.grey),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.red),
                      const SizedBox(width: 8),
                      const Text('To', style: TextStyle(fontSize: 12, color: Colors.black54)),
                      const SizedBox(width: 8),
                      Expanded(child: _campusDropdown(isFrom: false)),
                    ],
                  ),
                  const Divider(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          icon: Icons.calendar_today,
                          label: 'Date',
                          value: _formatDate(_date),
                          onTap: _pickDate,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          icon: Icons.payments_outlined,
                          label: 'Seats',
                          value: '$_seats seat${_seats > 1 ? 's' : ''}',
                          onTap: () => _pickSeats(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          icon: Icons.schedule,
                          label: 'From',
                          value: _start.format(context),
                          onTap: () => _pickTime(true),
                        ),
                      ),
                      const Text(' — ', style: TextStyle(fontWeight: FontWeight.w700)),
                      Expanded(
                        child: _field(
                          icon: Icons.schedule,
                          label: 'To',
                          value: _end.format(context),
                          onTap: () => _pickTime(false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _findRides,
                    icon: const Icon(Icons.search),
                    label: const Text('Find Rides'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                    onPressed: _postRequest,
                    icon: const Icon(Icons.request_page_outlined),
                    label: const Text('I Need a Ride (Request)'),
                  ),
                ],
              ),
            ),
          ),
          if (context.watch<AppStateProvider>().currentUser?.userId == 'admin1')
            _adminQuickCard(context),
        ],
      ),
    );
  }

  Widget _adminQuickCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: const Icon(Icons.admin_panel_settings, color: Color(0xFF1B6B4A), size: 32),
        title: const Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle: const Text('Verifications, reports and analytics'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminDashboardScreen()));
        },
      ),
    );
  }

  Widget _campusDropdown({required bool isFrom}) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: isFrom ? _from : _to,
        isExpanded: true,
        style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w600),
        items: Campus.sampleCampuses
            .map((c) => DropdownMenuItem(value: c.campusId, child: Text(c.campusName)))
            .toList(),
        onChanged: (v) {
          if (v == null) return;
          setState(() {
            if (isFrom) {
              if (v == _to) _to = _from == v ? _to : _to;
              _from = v;
            } else {
              _to = v;
            }
          });
        },
      ),
    );
  }

  Widget _field({required IconData icon, required String label, required String value, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, size: 16, color: Colors.grey.shade600), const SizedBox(width: 6), Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))]),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Future<void> _pickSeats() async {
    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('How many seats?'),
        children: [1, 2, 3, 4, 5]
            .map((s) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, s),
                  child: Text('$s seat${s > 1 ? 's' : ''}'),
                ))
            .toList(),
      ),
    );
    if (selected != null) setState(() => _seats = selected);
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final today = DateTime.now();
    final isTomorrow = date.year == today.year && date.month == today.month && date.day == today.day + 1;
    final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
    final label = isToday ? 'Today' : (isTomorrow ? 'Tomorrow' : '${date.day} ${months[date.month - 1]}');
    return label;
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}