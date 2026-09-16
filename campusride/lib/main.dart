import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_state_provider.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final appState = AppStateProvider();
  appState.repository.seedDemoData();

  runApp(
    ChangeNotifierProvider.value(
      value: appState,
      child: const CampusRideApp(),
    ),
  );
}
