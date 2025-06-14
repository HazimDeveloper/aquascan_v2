// lib/main.dart - SIMPLIFIED VERSION (No Authentication)
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'firebase_options.dart';
import 'screens/simplified/role_selection_screen.dart';
import 'services/database_service.dart';
import 'services/storage_service.dart';
import 'services/location_service.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final apiBaseUrl = 'http://10.0.2.2:8000'; // Replace with your API URL

  MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<DatabaseService>(
          create: (_) => DatabaseService(),
        ),
        Provider<StorageService>(
          create: (_) => StorageService(),
        ),
        Provider<LocationService>(
          create: (_) => LocationService(),
        ),
        Provider<ApiService>(
          create: (_) => ApiService(baseUrl: apiBaseUrl),
        ),
      ],
      child: MaterialApp(

        title: 'Water Quality Monitor - Simple',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue,dynamicSchemeVariant: DynamicSchemeVariant.vibrant)
        ),
        home: RoleSelectionScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}