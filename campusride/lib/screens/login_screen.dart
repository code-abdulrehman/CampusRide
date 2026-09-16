import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../widgets/common_widgets.dart';
import 'register_screen.dart';
import 'main_shell.dart';
import 'server_settings_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController(text: 'student1@campusride.test');
  final _passwordController = TextEditingController(text: 'CampusRide@123');
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login(AppStateProvider state) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      showAppSnack(context, 'Enter your email and password.', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final ok = await state.login(email, password);
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainShell()));
      } else {
        showAppSnack(context, 'Login failed.', error: true);
      }
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B6B4A),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.directions_car_filled, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 16),
              const Text('Welcome back!',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                'Sign in to your CampusRide account',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Institute Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Consumer<AppStateProvider>(
                builder: (context, state, _) => FilledButton(
                  onPressed: _loading ? null : () => _login(state),
                  child: _loading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Sign In'),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen()));
                },
                child: const Text('New student? Create an account'),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ServerSettingsScreen()));
                },
                icon: const Icon(Icons.dns_outlined, size: 18),
                label: const Text('Server settings (API URL)'),
              ),
              const SizedBox(height: 12),
              Divider(color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text(
                'Demo accounts',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.directions_car, size: 18),
                    label: const Text('Driver (driver1)'),
                    onPressed: () {
                      _emailController.text = 'driver1@campusride.test';
                      _passwordController.text = 'CampusRide@123';
                      _login(context.read<AppStateProvider>());
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.person, size: 18),
                    label: const Text('Student (student1)'),
                    onPressed: () {
                      _emailController.text = 'student1@campusride.test';
                      _passwordController.text = 'CampusRide@123';
                      _login(context.read<AppStateProvider>());
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.admin_panel_settings, size: 18),
                    label: const Text('Admin (admin)'),
                    onPressed: () {
                      _emailController.text = 'admin@campusride.test';
                      _passwordController.text = 'CampusRide@123';
                      _login(context.read<AppStateProvider>());
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}