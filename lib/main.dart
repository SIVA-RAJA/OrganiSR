import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';
import 'services/database_service.dart';
import 'services/storage_service.dart';
import 'theme/notion_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style to pure black
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize offline storage & SQLite
  await StorageService.instance.initialize();
  await DatabaseService.instance.database;

  runApp(const OrganiSRApp());
}

class OrganiSRApp extends StatelessWidget {
  const OrganiSRApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OrganiSR',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: NotionTheme.darkTheme,
      darkTheme: NotionTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}
