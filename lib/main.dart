import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/location_handler.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  // This is the entry point for Flutter code in the background
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load env variables in background isolate
  dotenv.load();
  
  LocationHandler.registerCallbacks();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await dotenv.load();
  // Register the callback dispatcher
  final callbackHandle = PluginUtilities.getCallbackHandle(callbackDispatcher);
  // Save this callback ID to use when starting the service
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthService(),
      child: MaterialApp(
        title: 'App v1',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: const LoginScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
