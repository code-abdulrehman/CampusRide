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
  final _userIdController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.presetUserId != null) {
      _userIdController.text = widget.presetUserId!;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

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

  Future<void> _submit() async {
    final userId = _userIdController.text.trim();
    if (userId.isEmpty) {
      showAppSnack(context, 'Enter the User ID of the person to report.', error: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      await context.read<AppStateProvider>().submitReport(
            reportedUserId: userId,
            rideId: widget.presetRideId,
            reason: _reason,
            description: _descriptionController.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      showAppSnack(context, 'Report submitted. Admin will review it.');
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report an Issue')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('User to report', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: _userIdController,
            enabled: widget.presetUserId == null,
            decoration: const InputDecoration(
              labelText: 'User ID',
              hintText: 'Paste the user ID here',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          if (widget.presetUserId != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(widget.presetUserId!, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
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
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            icon: _submitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.report),
            label: const Text('Submit Report'),
          ),
        ],
      ),
    );
  }
}