import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../widgets/common_widgets.dart';
import 'login_screen.dart';

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
  final _departmentController = TextEditingController();
  final _semesterController = TextEditingController();
  String _mainCampus = 'Campus A';
  bool _agree = false;

  static const campuses = ['Campus A', 'Campus B', 'Campus C', 'Main Campus'];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _studentIdController.dispose();
    _phoneController.dispose();
    _departmentController.dispose();
    _semesterController.dispose();
    super.dispose();
  }

  void _register() {
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
    final state = context.read<AppStateProvider>();
    state.register(
      name: name,
      email: email,
      studentId: studentId,
      phone: _phoneController.text.trim(),
      department: _departmentController.text.trim(),
      semester: _semesterController.text.trim(),
      mainCampus: _mainCampus,
    );
    showAppSnack(context, 'Account created! Complete verification to start booking.');
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
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
            TextField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone Number (optional)', prefixIcon: Icon(Icons.phone_outlined))),
            const SizedBox(height: 14),
            TextField(controller: _departmentController, decoration: const InputDecoration(labelText: 'Department', prefixIcon: Icon(Icons.school_outlined))),
            const SizedBox(height: 14),
            TextField(controller: _semesterController, decoration: const InputDecoration(labelText: 'Semester', prefixIcon: Icon(Icons.menu_book_outlined))),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _mainCampus,
              decoration: const InputDecoration(labelText: 'Main Campus', prefixIcon: Icon(Icons.location_city)),
              items: campuses.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _mainCampus = v ?? _mainCampus),
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
            FilledButton(onPressed: _register, child: const Text('Create Account')),
          ],
        ),
      ),
    );
  }
}