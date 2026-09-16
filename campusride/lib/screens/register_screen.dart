import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../widgets/common_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _departmentController = TextEditingController();
  final _semesterController = TextEditingController();
  String? _mainCampusId;
  bool _agree = false;
  bool _submitting = false;

  void _disposeControllers() {
    _nameController.dispose();
    _emailController.dispose();
    _studentIdController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _departmentController.dispose();
    _semesterController.dispose();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final studentId = _studentIdController.text.trim();
    if (name.isEmpty || email.isEmpty || studentId.isEmpty) {
      showAppSnack(context, 'Name, email and student ID are required.', error: true);
      return;
    }
    if (!_agree) {
      showAppSnack(context, 'Please agree to the community safety policy.', error: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      final state = context.read<AppStateProvider>();
      await state.register(
        name: name,
        email: email,
        studentId: studentId,
        password: _passwordController.text.trim().isEmpty ? null : _passwordController.text.trim(),
        phone: _phoneController.text.trim(),
        department: _departmentController.text.trim(),
        semester: _semesterController.text.trim(),
        mainCampus: _mainCampusId,
      );
      if (!mounted) return;
      showAppSnack(context, 'Account created! Complete verification to start booking.');
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
    final state = context.watch<AppStateProvider>();
    final campuses = state.campuses;
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Closed community — only verified students can join.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 20),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline))),
            const SizedBox(height: 14),
            TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Institute Email', prefixIcon: Icon(Icons.email_outlined))),
            const SizedBox(height: 14),
            TextField(controller: _studentIdController, decoration: const InputDecoration(labelText: 'Student Registration ID', prefixIcon: Icon(Icons.badge_outlined))),
            const SizedBox(height: 14),
            TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline))),
            const SizedBox(height: 14),
            TextField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone Number (optional)', prefixIcon: Icon(Icons.phone_outlined))),
            const SizedBox(height: 14),
            TextField(controller: _departmentController, decoration: const InputDecoration(labelText: 'Department', prefixIcon: Icon(Icons.school_outlined))),
            const SizedBox(height: 14),
            TextField(controller: _semesterController, decoration: const InputDecoration(labelText: 'Semester', prefixIcon: Icon(Icons.menu_book_outlined))),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _mainCampusId,
              decoration: const InputDecoration(labelText: 'Main Campus', prefixIcon: Icon(Icons.location_city)),
              items: campuses.map((c) => DropdownMenuItem(value: c.campusId, child: Text(c.campusName))).toList(),
              onChanged: (v) => setState(() => _mainCampusId = v),
            ),
            const SizedBox(height: 10),
            CheckboxListTile(
              value: _agree,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('I agree to only use verified campus accounts and follow community safety rules.', style: TextStyle(fontSize: 13)),
              onChanged: (v) => setState(() => _agree = v ?? false),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _register,
              child: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Create Account'),
            ),
          ],
        ),
      ),
    );
  }
}