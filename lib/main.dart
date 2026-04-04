import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

import 'services/agent_provider.dart';
import 'services/settings_service.dart';
import 'services/notification_service.dart';
import 'services/error_pattern_db.dart';
import 'services/health_check_service.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'theme/app_theme.dart';

void main() {
  _setupLogging();
  runApp(const AutoCureApp());
}

void _setupLogging() {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    debugPrint(
      '[${record.level.name}] ${record.loggerName}: ${record.message}'
      '${record.error != null ? '\n  ${record.error}' : ''}',
    );
  });
}

class AutoCureApp extends StatelessWidget {
  const AutoCureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SettingsService()..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => NotificationService(),
        ),
        ChangeNotifierProvider(
          create: (_) => ErrorPatternDatabase()..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => AgentProvider(projectRoot: '.'),
        ),
        Provider(
          create: (ctx) => HealthCheckService(
            notifications: ctx.read<NotificationService>(),
          ),
          dispose: (_, service) => service.dispose(),
        ),
      ],
      child: Consumer<SettingsService>(
        builder: (context, settings, _) {
          final isDark = settings.settings.darkMode;
          return MaterialApp(
            title: 'AutoCure - Self-Healing Agent',
            debugShowCheckedModeBanner: false,
            themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            home: const DashboardScreen(),
          );
        },
      ),
    );
  }
}
