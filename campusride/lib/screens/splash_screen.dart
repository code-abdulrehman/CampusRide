import 'dart:async';
import 'package:flutter/material.dart';
import '../providers/app_state_provider.dart';
import 'package:provider/provider.dart';
import 'login_screen.dart';
import 'main_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 2), _goToEntry);
  }

  void _goToEntry() {
    if (!mounted) return;
    final state = context.read<AppStateProvider>();
    if (state.currentUser != null && state.currentUser!.accountStatus.index == 0) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B6B4A),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.directions_car_filled, size: 56, color: Color(0xFF1B6B4A)),
              ),
              const SizedBox(height: 20),
              const Text(
                'CampusRide',
                style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Verified Student-to-Student\nInter-Campus Ride Sharing',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}