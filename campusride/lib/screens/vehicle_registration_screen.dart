import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/enums.dart';
import '../providers/app_state_provider.dart';
import '../widgets/common_widgets.dart';

class VehicleRegistrationScreen extends StatefulWidget {
  const VehicleRegistrationScreen({super.key});

  @override
  State<VehicleRegistrationScreen> createState() => _VehicleRegistrationScreenState();
}

class _VehicleRegistrationScreenState extends State<VehicleRegistrationScreen> {
  final _companyController = TextEditingController(text: 'Honda');
  final _modelController = TextEditingController(text: 'Civic');
  final _colorController = TextEditingController(text: 'White');
  final _regController = TextEditingController(text: 'LEA-9999');
  int _year = 2023;
  int _totalSeats = 5;
  bool _submitting = false;

  @override
  void dispose() {
    _companyController.dispose();
    _modelController.dispose();
    _colorController.dispose();
    _regController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final company = _companyController.text.trim();
    final model = _modelController.text.trim();
    final reg = _regController.text.trim();
    if (company.isEmpty || model.isEmpty || reg.isEmpty) {
      showAppSnack(context, 'Company, model and registration number are required.', error: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      final state = context.read<AppStateProvider>();
      await state.addVehicle(
        company: company,
        model: model,
        modelYear: _year,
        color: _colorController.text.trim().isEmpty ? 'White' : _colorController.text.trim(),
        registrationNumber: reg,
        totalSeats: _totalSeats,
      );
      if (!mounted) return;
      await state.loadMyVehicles();
      showAppSnack(context, 'Vehicle submitted for verification.');
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
    final vehicles = context.watch<AppStateProvider>().getMyVehicles();
    return Scaffold(
      appBar: AppBar(title: const Text('Vehicles')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final v in vehicles)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: Icon(v.isVerified ? Icons.directions_car : Icons.hourglass_top, color: v.isVerified ? Colors.green : Colors.orange),
                title: Text('${v.company} ${v.model} ${v.modelYear}'),
                subtitle: Text('${v.color} • ${v.registrationNumber} • ${v.totalSeats} seats'),
                trailing: StatusChip(
                  label: v.verificationStatus == VehicleStatus.verified ? 'Verified' : 'Pending',
                  color: v.verificationStatus == VehicleStatus.verified ? Colors.green : Colors.orange,
                ),
              ),
            ),
          if (vehicles.isEmpty)
            const EmptyState(icon: Icons.directions_car_outlined, title: 'No vehicles', message: 'Register your first vehicle.'),
          const SizedBox(height: 16),
          const Text('Register New Vehicle', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          TextField(
            controller: _companyController,
            decoration: const InputDecoration(labelText: 'Company', prefixIcon: Icon(Icons.business)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _modelController,
            decoration: const InputDecoration(labelText: 'Model', prefixIcon: Icon(Icons.tag)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _colorController,
                  decoration: const InputDecoration(labelText: 'Color', prefixIcon: Icon(Icons.palette_outlined)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _year,
                  decoration: const InputDecoration(labelText: 'Year'),
                  items: [2020, 2021, 2022, 2023, 2024, 2025, 2026]
                      .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                      .toList(),
                  onChanged: (v) => setState(() => _year = v ?? 2023),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _regController,
            decoration: const InputDecoration(labelText: 'Registration Number', prefixIcon: Icon(Icons.confirmation_number_outlined)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.event_seat, size: 20),
              const SizedBox(width: 12),
              const Text('Total seats:'),
              Expanded(
                child: Slider(
                  value: _totalSeats.toDouble(),
                  min: 2,
                  max: 8,
                  divisions: 6,
                  onChanged: (v) => setState(() => _totalSeats = v.round()),
                ),
              ),
              Text('$_totalSeats'),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _submitting ? null : _register,
            icon: _submitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.add),
            label: const Text('Register Vehicle'),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Vehicle verification requires registration docs. Admin approval is needed before the vehicle can be used for rides.',
              style: TextStyle(fontSize: 13, color: Colors.blueGrey),
            ),
          ),
        ],
      ),
    );
  }
}