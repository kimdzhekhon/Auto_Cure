import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/agent_provider.dart';
import 'screens/dashboard/dashboard_screen.dart';

void main() {
  runApp(const AutoCureApp());
}

class AutoCureApp extends StatelessWidget {
  const AutoCureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AgentProvider(projectRoot: '.'),
      child: MaterialApp(
        title: 'AutoCure - Self-Healing Agent',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const DashboardScreen(),
      ),
    );
  }
}
