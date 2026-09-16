import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import 'home_screen.dart';
import 'my_rides_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'admin_dashboard_screen.dart';
import 'create_ride_screen.dart';
import '../widgets/common_widgets.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  bool get _isAdmin {
    final user = context.read<AppStateProvider>().currentUser;
    return user?.isAdmin ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _isAdmin;
    final pages = <Widget>[
      const HomeScreen(),
      const MyRidesScreen(),
      const ProfileScreen(),
      const NotificationsScreen(),
      if (isAdmin) const AdminDashboardScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          const NavigationDestination(icon: Icon(Icons.directions_car_outlined), selectedIcon: Icon(Icons.directions_car), label: 'My Rides'),
          const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
          Consumer<AppStateProvider>(
            builder: (context, state, _) {
              final count = state.unreadCount;
              return NavigationDestination(
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  child: const Icon(Icons.notifications_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  child: const Icon(Icons.notifications),
                ),
                label: 'Updates',
              );
            },
          ),
          if (isAdmin)
            const NavigationDestination(icon: Icon(Icons.admin_panel_settings_outlined), selectedIcon: Icon(Icons.admin_panel_settings), label: 'Admin'),
        ],
      ),
      floatingActionButton: _index == 0
          ? FloatingActionButton.extended(
              onPressed: _openCreateRide,
              backgroundColor: const Color(0xFF1B6B4A),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text(
                'Offer Ride',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            )
          : null,
    );
  }

  void _openCreateRide() {
    final state = context.read<AppStateProvider>();
    final user = state.currentUser;
    if (user == null) {
      showAppSnack(context, 'Please login first.', error: true);
      return;
    }
    if (!user.isDriverVerified) {
      showAppSnack(context, 'Verify as a driver in your profile to offer rides.', error: true);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateRideScreen()));
  }
}