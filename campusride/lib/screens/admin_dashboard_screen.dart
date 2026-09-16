import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../widgets/common_widgets.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
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
      state.loadAdminDashboard(),
      state.loadAdminUsers(),
      state.loadPendingDrivers(),
      state.loadPendingVehicles(),
      state.loadAdminReports(),
      state.loadMyVehicles(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();
    final dash = state.adminDashboard;

    final students = state.adminUsers;
    final pendingReportsList = state.adminReports;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loading ? null : _refresh,
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Verify'),
              Tab(text: 'Reports'),
            ],
          ),
        ),
        body: _loading && students.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _overview(state, dash),
                  _verify(state),
                  _reports(state, pendingReportsList),
                ],
              ),
      ),
    );
  }

  Widget _overview(AppStateProvider state, Map<String, dynamic> dash) {
    final totalUsers = (dash['totalUsers'] ?? 0).toString();
    final totalStudents = (dash['totalStudents'] ?? 0).toString();
    final driversPending = (dash['driversPending'] ?? 0).toString();
    final vehiclesPending = (dash['vehiclesPending'] ?? 0).toString();
    final openReports = (dash['openReports'] ?? 0).toString();
    final activeRides = (dash['activeRides'] ?? 0).toString();
    final ridesToday = (dash['ridesToday'] ?? 0).toString();
    final totalRides = (dash['totalRides'] ?? 0).toString();
    final suspendedUsers = (dash['suspendedUsers'] ?? 0).toString();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Platform', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.6,
          children: [
            _statCard(Icons.group, Colors.blue, totalUsers, 'Registered'),
            _statCard(Icons.verified_user, Colors.green, totalStudents, 'Verified Students'),
            _statCard(Icons.directions_car, Colors.teal, driversPending, 'Drivers Pending'),
            _statCard(Icons.tire_repair, Colors.purple, vehiclesPending, 'Vehicles Pending'),
            _statCard(Icons.route, Colors.orange, activeRides, 'Active Rides'),
            _statCard(Icons.calendar_today, Colors.indigo, ridesToday, 'Rides Today'),
            _statCard(Icons.history, Colors.brown, totalRides, 'Total Rides'),
            _statCard(Icons.report, Colors.red, openReports, 'Open Reports'),
            _statCard(Icons.block, Colors.orange, suspendedUsers, 'Suspended'),
          ],
        ),
      ],
    );
  }

  Widget _statCard(IconData icon, Color color, String value, String label) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(children: [Icon(icon, color: color), const Spacer(), const Icon(Icons.more_horiz, size: 16, color: Colors.grey)]),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _verify(AppStateProvider state) {
    final pendingStudents = state.adminUsers.where((u) => _str(u['studentVerified']) == 'PENDING').toList();
    final pendingDrivers = state.pendingDrivers;
    final pendingVehicles = state.pendingVehicles;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Student Verifications', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        ...pendingStudents.map((u) => _verifyTile(
              title: _str(u['fullName']),
              subtitle: '${_str(u['email'])} • ${_str(u['studentId'])}',
              onApprove: () => state.verifyStudent(_str(u['id'])),
            )),
        if (pendingStudents.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('All students verified ✅', style: TextStyle(color: Colors.green.shade700)),
          ),
        const Divider(height: 28),
        const Text('Driver Verifications', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        ...pendingDrivers.map((u) => _verifyTile(
              title: _str(u['fullName']),
              subtitle: '${_str(u['email'])} • ${u['vehicleCount'] ?? 0} vehicle(s)',
              onApprove: () => state.verifyDriver(_str(u['id'])),
            )),
        if (pendingDrivers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('No pending driver applications', style: TextStyle(color: Colors.grey.shade600)),
          ),
        const Divider(height: 28),
        const Text('Vehicle Verifications', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        ...pendingVehicles.map((v) => _verifyTile(
              title: '${_str(v['company'])} ${_str(v['model'])} (${_str(v['registrationNumber'])})',
              subtitle: '${_str(v['vehicleType'])} • ${v['totalSeats'] ?? '?'} seats',
              onApprove: () => state.verifyVehicle(_str(v['id'])),
            )),
        if (pendingVehicles.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('No pending vehicles', style: TextStyle(color: Colors.grey.shade600)),
          ),
      ],
    );
  }

  Widget _verifyTile({required String title, required String subtitle, required VoidCallback onApprove}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: const Size(90, 38)),
          onPressed: onApprove,
          child: const Text('Approve'),
        ),
      ),
    );
  }

  Widget _reports(AppStateProvider state, List<Map<String, dynamic>> reports) {
    final pendingReports = reports.where((r) => _str(r['status']) == 'OPEN').toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (pendingReports.isEmpty)
          const EmptyState(icon: Icons.done_all, title: 'No pending reports', message: 'All reports have been handled.')
        else
          ...pendingReports.map((r) {
            final reported = (r['reportedUser'] as Map<String, dynamic>?)?['fullName'] ?? 'Unknown';
            final reason = _humanizeReason(_str(r['reason']));
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.report, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(reported, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const Spacer(),
                        StatusChip(label: reason, color: Colors.orange),
                      ],
                    ),
                    if ((r['description'] ?? '').toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text((r['description'] ?? '').toString()),
                      ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => state.resolveReport(_str(r['id']), status: 'WARNED', adminAction: 'warning issued'),
                          child: const Text('Warning'),
                        ),
                        TextButton(
                          onPressed: () => state.resolveReport(_str(r['id']), status: 'RESOLVED', adminAction: 'temporary suspension'),
                          child: const Text('Suspend'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, minimumSize: const Size(100, 38)),
                          onPressed: () {
                            state.resolveReport(_str(r['id']), status: 'DISMISSED', adminAction: 'permanent ban');
                            showAppSnack(context, 'User permanently banned.');
                          },
                          child: const Text('Ban'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 10),
        const Text('All Users', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        ...state.adminUsers.map((u) {
          if (_str(u['role']) == 'ADMIN') return const SizedBox.shrink();
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 2),
            child: ListTile(
              dense: true,
              leading: Avatar(name: _str(u['fullName']), radius: 16),
              title: Text(_str(u['fullName'])),
              subtitle: Text(_str(u['email'])),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_str(u['accountStatus']) == 'ACTIVE' && _str(u['role']) != 'ADMIN')
                    IconButton(
                      icon: const Icon(Icons.block, color: Colors.red),
                      tooltip: 'Suspend',
                      onPressed: () {
                        state.suspendUser(_str(u['id']));
                        showAppSnack(context, '${_str(u['fullName'])} suspended.');
                      },
                    ),
                  StatusChip(
                    label: _str(u['driverVerified']) == 'VERIFIED'
                        ? 'Driver'
                        : (_str(u['studentVerified']) == 'VERIFIED' ? 'Student' : 'None'),
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  String _str(Object? v) => v?.toString() ?? '';

  String _humanizeReason(String reason) {
    final lower = reason.toLowerCase();
    const map = {
      'dangerous_driving': 'Dangerous driving',
      'harassment': 'Harassment',
      'fake_details': 'Fake details',
      'no_show': 'No-show',
      'excessive_charging': 'Excessive charging',
      'misbehavior': 'Misbehavior',
      'wrong_pickup': 'Wrong pickup',
      'spam': 'Spam',
      'other': 'Other',
    };
    return map[lower] ?? reason;
  }
}