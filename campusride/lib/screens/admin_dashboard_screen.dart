import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/enums.dart';
import '../providers/app_state_provider.dart';
import '../widgets/common_widgets.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();
    final repo = state.repository;

    final students = repo.users.where((u) => u.userId != 'admin1').toList();
    final verifiedDrivers = students.where((u) => u.isDriverVerified).length;
    final verifiedStudents = students.where((u) => u.isStudentVerified).length;
    final verifiedVehicles = repo.vehicles.where((v) => v.isVerified).length;
    final allRides = repo.rides;
    final activeRides = allRides.where((r) => r.rideStatus == RideStatus.open || r.rideStatus == RideStatus.full).length;
    final completedRides = allRides.where((r) => r.rideStatus == RideStatus.completed).length;
    final cancelledRides = allRides.where((r) => r.rideStatus == RideStatus.cancelled).length;
    final pendingReports = repo.reports.where((r) => r.status == ReportStatus.pending).length;

    final pendingVehicles = repo.vehicles.where((v) => v.verificationStatus == VehicleStatus.pending).toList();
    final pendingDrivers = students.where((u) => u.verificationStatus == UserVerificationStatus.studentVerified && !u.isDriverVerified).toList();
    final pendingStudents = students.where((u) => !u.isStudentVerified).toList();
    final pendingReportsList = repo.reports.where((r) => r.status == ReportStatus.pending).toList();

    final routeCounts = <String, int>{};
    for (final r in allRides) {
      final key = '${r.origin} → ${r.destination}';
      routeCounts[key] = (routeCounts[key] ?? 0) + 1;
    }
    final topRoutes = routeCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          automaticallyImplyLeading: false,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Verify'),
              Tab(text: 'Reports'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _overview(state, students.length, verifiedStudents, verifiedDrivers, verifiedVehicles, activeRides, completedRides, cancelledRides, pendingReports, topRoutes),
            _verify(state, pendingStudents, pendingDrivers, pendingVehicles),
            _reports(state, pendingReportsList),
          ],
        ),
      ),
    );
  }

  Widget _overview(AppStateProvider state, int students, int verifiedStudents, int verifiedDrivers, int verifiedVehicles, int activeRides, int completedRides, int cancelledRides, int pendingReports, List<MapEntry<String, int>> topRoutes) {
    final totalBookings = state.repository.bookings.length;
    final costSaved = state.repository.bookings.fold(0.0, (p, b) => p + (b.status != BookingStatus.cancelled ? b.amountPaid : 0));
    final avgOccupancy = completedRides > 0 ? (state.repository.bookings.where((b) => b.status == BookingStatus.completed).length / (completedRides + 1)).toStringAsFixed(1) : '0.0';

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
            _statCard(Icons.group, Colors.blue, '$students', 'Registered'),
            _statCard(Icons.verified_user, Colors.green, '$verifiedStudents', 'Verified Students'),
            _statCard(Icons.directions_car, Colors.teal, '$verifiedDrivers', 'Verified Drivers'),
            _statCard(Icons.tire_repair, Colors.purple, '$verifiedVehicles', 'Verified Vehicles'),
            _statCard(Icons.route, Colors.orange, '$activeRides', 'Active Rides'),
            _statCard(Icons.check_circle, Colors.green, '$completedRides', 'Completed'),
            _statCard(Icons.cancel, Colors.red, '$cancelledRides', 'Cancelled'),
            _statCard(Icons.report, Colors.red, '$pendingReports', 'Pending Reports'),
            _statCard(Icons.event_seat, Colors.blueGrey, avgOccupancy, 'Avg Seats/Ride'),
            _statCard(Icons.savings, Colors.green, 'Rs.${costSaved.toStringAsFixed(0)}', 'Cost Shared'),
            _statCard(Icons.confirmation_number, Colors.indigo, '$totalBookings', 'Bookings'),
          ],
        ),
        const SizedBox(height: 12),
        const Text('Popular Routes', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 8),
        ...topRoutes.map((e) => Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: const Icon(Icons.route),
                title: Text(e.key),
                trailing: Chip(label: Text('${e.value} rides')),
              ),
            )),
        if (topRoutes.isEmpty)
          const EmptyState(icon: Icons.route, title: 'No route data', message: 'Ride data will show up here.'),
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

  Widget _verify(AppStateProvider state, List pendingStudents, List pendingDrivers, List pendingVehicles) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Student Verifications', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        ...pendingStudents.map((u) => _verifyTile(
              title: u.name,
              subtitle: '${u.email} • ${u.studentId}',
              onApprove: () => state.verifyStudent(u.userId),
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
              title: u.name,
              subtitle: '${u.email} • Apply for driver role',
              onApprove: () => state.verifyDriver(u.userId),
            )),
        if (pendingDrivers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('No pending driver applications', style: TextStyle(color: Colors.grey.shade600)),
          ),
        const Divider(height: 28),
        const Text('Vehicle Verifications', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        ...pendingVehicles.map((v) {
          final owner = state.repository.getUserById(v.ownerUserId);
          return _verifyTile(
            title: '${v.company} ${v.model} (${v.registrationNumber})',
            subtitle: 'Owner: ${owner?.name ?? 'Unknown'}',
            onApprove: () => state.verifyVehicle(v.vehicleId),
          );
        }),
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

  Widget _reports(AppStateProvider state, List pendingReports) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (pendingReports.isEmpty)
          const EmptyState(icon: Icons.done_all, title: 'No pending reports', message: 'All reports have been handled.')
        else
          ...pendingReports.map((r) {
            final reported = state.repository.getUserById(r.reportedUserId);
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
                        Text(reported?.name ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w700)),
                        const Spacer(),
                        StatusChip(label: r.reason.name, color: Colors.orange),
                      ],
                    ),
                    if (r.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(r.description),
                      ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => state.resolveReport(r.reportId, ReportStatus.warning),
                          child: const Text('Warning'),
                        ),
                        TextButton(
                          onPressed: () => state.resolveReport(r.reportId, ReportStatus.temporarySuspension),
                          child: const Text('Suspend'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, minimumSize: const Size(100, 38)),
                          onPressed: () {
                            state.resolveReport(r.reportId, ReportStatus.permanentBan);
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
        ...state.repository.users.map((u) {
          if (u.userId == 'admin1') return const SizedBox.shrink();
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 2),
            child: ListTile(
              dense: true,
              leading: Avatar(name: u.name, radius: 16),
              title: Text(u.name),
              subtitle: Text(u.email),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (u.accountStatus == AccountStatus.active)
                    IconButton(
                      icon: const Icon(Icons.block, color: Colors.red),
                      tooltip: 'Suspend',
                      onPressed: () {
                        state.suspendUser(u.userId);
                        showAppSnack(context, '${u.name} suspended.');
                      },
                    ),
                  statusChipFor(u.verificationStatus),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget statusChipFor(UserVerificationStatus status) {
    final (label, color) = switch (status) {
      UserVerificationStatus.none => ('None', Colors.grey),
      UserVerificationStatus.studentPending => ('Pending', Colors.orange),
      UserVerificationStatus.studentVerified => ('Student', Colors.blue),
      UserVerificationStatus.driverPending => ('Driver Pending', Colors.deepOrange),
      UserVerificationStatus.driverVerified => ('Driver', Colors.green),
    };
    return StatusChip(label: label, color: color);
  }
}