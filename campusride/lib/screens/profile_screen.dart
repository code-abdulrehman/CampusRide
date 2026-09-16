import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../widgets/common_widgets.dart';
import 'vehicle_registration_screen.dart';
import 'sos_screen.dart';
import 'report_screen.dart';
import 'admin_dashboard_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();
    final user = state.currentUser;
    if (user == null) {
      return Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
            child: const Text('Login'),
          ),
        ),
      );
    }

    final isAdmin = user.isAdmin;
    final myVehicles = state.getMyVehicles();
    final unverifiedVehicles = myVehicles.where((v) => !v.isVerified).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await state.logout();
              if (context.mounted) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Avatar(name: user.name, radius: 44),
                const SizedBox(height: 12),
                Text(user.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                Text(user.email, style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    VerifiedBadge(
                      label: 'Student Verified',
                      verified: user.isStudentVerified,
                    ),
                    if (user.isDriverVerified)
                      const VerifiedBadge(label: 'Driver Verified'),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _stat(user.rating.toStringAsFixed(1), 'Rating'),
                    _stat('${user.completedRides}', 'Rides'),
                    _stat('${user.reliabilityScore.toStringAsFixed(0)}%', 'Reliable'),
                  ],
                ),
              ],
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('Student ID'),
                  subtitle: Text(user.studentId),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.school_outlined),
                  title: const Text('Department'),
                  subtitle: Text('${user.department} • ${user.semester}'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.location_city),
                  title: const Text('Main Campus'),
                  subtitle: Text(user.mainCampus),
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'Verification & Safety'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                if (!user.isStudentVerified)
                  ListTile(
                    leading: const Icon(Icons.verified_user, color: Colors.orange),
                    title: const Text('Verify Student Account'),
                    subtitle: const Text('Use your registration ID + institute email'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      try {
                        await state.submitStudentVerification();
                        if (context.mounted) showAppSnack(context, 'Student verification submitted!');
                      } catch (e) {
                        if (context.mounted) showAppSnack(context, '$e', error: true);
                      }
                    },
                  ),
                if (!user.isDriverVerified && user.isStudentVerified)
                  ListTile(
                    leading: const Icon(Icons.directions_car, color: Colors.orange),
                    title: const Text('Apply to Become a Driver'),
                    subtitle: const Text('Licence + vehicle verification required'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      try {
                        await state.submitDriverVerification();
                        if (context.mounted) showAppSnack(context, 'Driver verification submitted!');
                      } catch (e) {
                        if (context.mounted) showAppSnack(context, '$e', error: true);
                      }
                    },
                  ),
                if (user.isDriverVerified)
                  ListTile(
                    leading: const Icon(Icons.verified, color: Colors.green),
                    title: const Text('Driver Account Verified'),
                    subtitle: const Text('You can offer rides'),
                    trailing: const Icon(Icons.check_circle, color: Colors.green),
                  ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.directions_car_outlined),
                  title: Text('My Vehicles (${myVehicles.length})'),
                  subtitle: Text(
                    unverifiedVehicles > 0
                        ? '$unverifiedVehicles vehicle(s) awaiting verification'
                        : (myVehicles.isEmpty ? 'Register a car to offer rides' : 'All vehicles verified'),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VehicleRegistrationScreen())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.sos, color: Colors.red),
                  title: const Text('SOS / Emergency'),
                  subtitle: const Text('Emergency contacts & ride safety'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SosScreen())),
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'More'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.star_outline, color: Colors.amber),
                  title: const Text('Rate a Completed Ride'),
                  subtitle: const Text('Share feedback about your last trip'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    showAppSnack(context, 'Open My Rides → tap the ★ on a completed ride to rate it.');
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.report_outlined, color: Colors.red),
                  title: const Text('Report an Issue'),
                  subtitle: const Text('Report a user about a ride'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportScreen())),
                ),
                if (isAdmin) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.admin_panel_settings, color: Color(0xFF1B6B4A)),
                    title: const Text('Admin Dashboard'),
                    subtitle: const Text('Verifications, reports & analytics'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen())),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1B6B4A))),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }
}