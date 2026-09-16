import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/enums.dart';
import '../providers/app_state_provider.dart';
import '../widgets/common_widgets.dart';

class ReportScreen extends StatefulWidget {
  final String? presetUserId;
  final String? presetRideId;

  const ReportScreen({super.key, this.presetUserId, this.presetRideId});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  ReportReason _reason = ReportReason.dangerousDriving;
  final _descriptionController = TextEditingController();
  String? _targetUserId;

  static const _reasons = [
    (ReportReason.dangerousDriving, 'Dangerous driving'),
    (ReportReason.harassment, 'Harassment'),
    (ReportReason.fakeDetails, 'Fake vehicle details'),
    (ReportReason.noShow, 'No-show'),
    (ReportReason.excessiveCharging, 'Excessive charging'),
    (ReportReason.misbehavior, 'Misbehavior'),
    (ReportReason.wrongPickup, 'Wrong pickup'),
    (ReportReason.spam, 'Spam'),
    (ReportReason.other, 'Other'),
  ];

  @override
  void initState() {
    super.initState();
    _targetUserId = widget.presetUserId;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_targetUserId == null) {
      showAppSnack(context, 'Please select a user to report.', error: true);
      return;
    }
    context.read<AppStateProvider>().submitReport(
          reportedUserId: _targetUserId!,
          rideId: widget.presetRideId,
          reason: _reason,
          description: _descriptionController.text.trim(),
        );
    Navigator.of(context).pop();
    showAppSnack(context, 'Report submitted. Admin will review it.');
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();
    final users = state.repository.users.where((u) => u.userId != state.currentUser?.userId).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Report an Issue')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Choose the user involved in the incident.', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _targetUserId,
            decoration: const InputDecoration(labelText: 'User', prefixIcon: Icon(Icons.person_outline)),
            items: users.map((u) => DropdownMenuItem(value: u.userId, child: Text(u.name))).toList(),
            onChanged: (v) => setState(() => _targetUserId = v),
          ),
          const SizedBox(height: 16),
          const Text('Reason', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ..._reasons.map((pair) => InkWell(
                onTap: () => setState(() => _reason = pair.$1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        _reason == pair.$1 ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: _reason == pair.$1 ? const Color(0xFF1B6B4A) : Colors.grey.shade400,
                      ),
                      const SizedBox(width: 10),
                      Text(pair.$2),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Description (optional)', hintText: 'What happened?'),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _submit,
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            icon: const Icon(Icons.report),
            label: const Text('Submit Report'),
          ),
        ],
      ),
    );
  }
}