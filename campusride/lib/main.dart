import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/api_config.dart';
import 'providers/app_state_provider.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.load();
  final appState = AppStateProvider();
  await appState.init();

  runApp(
    ChangeNotifierProvider.value(
      value: appState,
      child: const CampusRideApp(),
    ),
  );
}