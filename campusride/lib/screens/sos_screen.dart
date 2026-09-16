import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../widgets/common_widgets.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  bool _triggered = false;

  void _trigger() {
    final state = context.read<AppStateProvider>();
    state.addNotificationForCurrentUser(
      title: 'SOS Alert Sent',
      message: 'Your emergency contact and institute security have been notified with your ride details.',
    );
    setState(() => _triggered = true);
    showAppSnack(context, 'SOS triggered — help is on the way.');
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();
    final user = state.currentUser;
    if (user == null) return const SizedBox();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety & Emergency'),
        backgroundColor: Colors.red.shade800,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: _triggered
                ? Column(
                    children: const [
                      Icon(Icons.check_circle, color: Colors.red, size: 48),
                      SizedBox(height: 10),
                      Text('SOS Alert Sent', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                      SizedBox(height: 4),
                      Text('Emergency contact + institute security notified. Ride details shared.', textAlign: TextAlign.center),
                    ],
                  )
                : Column(
                    children: [
                      const Text(
                        'In an emergency, tap SOS to alert your emergency contact and institute security immediately.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: Material(
                          shape: const CircleBorder(),
                          color: Colors.red.shade700,
                          elevation: 8,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _trigger,
                            child: const Center(
                              child: Text('SOS', style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          const SectionHeader(title: 'Emergency Contact'),
          Card(
            margin: EdgeInsets.zero,
            child: user.emergencyContactPhone == null || user.emergencyContactPhone!.isEmpty
                ? ListTile(
                    leading: const Icon(Icons.person_add_alt, color: Colors.orange),
                    title: const Text('No emergency contact set'),
                    subtitle: const Text('Tap to add one'),
                    onTap: () => _addContact(context),
                  )
                : ListTile(
                    leading: const Icon(Icons.contact_phone, color: Colors.green),
                    title: Text(user.emergencyContactName ?? 'Emergency Contact'),
                    subtitle: Text(user.emergencyContactPhone ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _addContact(context),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.local_police, color: Colors.blue),
                  title: const Text('Institute Security'),
                  subtitle: const Text('University Security Office • 111-000-786'),
                  trailing: const Icon(Icons.call),
                  onTap: () => showAppSnack(context, 'Calling institute security (demo)'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.share, color: Colors.teal),
                  title: const Text('Share Ride Details'),
                  subtitle: const Text('Send ride info to a trusted contact'),
                  trailing: const Icon(Icons.share),
                  onTap: () => showAppSnack(context, 'Ride details shared with your contacts'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline, color: Colors.grey),
                  title: const Text('Safety tips'),
                  subtitle: const Text('Use Ride PIN • Stick to verified riders • Share your trip'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Future<void> _addContact(BuildContext context) async {
    final provider = context.read<AppStateProvider>();
    final nameController = TextEditingController(text: provider.currentUser?.emergencyContactName ?? '');
    final phoneController = TextEditingController(text: provider.currentUser?.emergencyContactPhone ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Emergency Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Full Name')),
            const SizedBox(height: 12),
            TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone Number')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == true) {
      provider.setEmergencyContact(
        nameController.text.trim(),
        phoneController.text.trim(),
      );
      if (context.mounted) showAppSnack(context, 'Emergency contact saved.');
    }
  }
}