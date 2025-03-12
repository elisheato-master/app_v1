import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final String groupName;
  final String userName;

  const HomeScreen({
    Key? key,
    required this.groupName,
    required this.userName,
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const platform = MethodChannel('com.example.app_v1/location');
  String _status = "Tracking in background...";
  
  Future<void> _stopTracking() async {
    try {
      await platform.invokeMethod('stopLocationService');
      
      // Clear saved preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const UserInfoScreen()),
        );
      }
    } on PlatformException catch (e) {
      setState(() {
        _status = "Failed to stop tracking: ${e.message}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Tracking'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Group: ${widget.groupName}',
                style: Theme.of(context).textTheme.headline6,
              ),
              const SizedBox(height: 8),
              Text(
                'User: ${widget.userName}',
                style: Theme.of(context).textTheme.headline6,
              ),
              const SizedBox(height: 24),
              const Icon(
                Icons.location_on,
                size: 64,
                color: Colors.blue,
              ),
              const SizedBox(height: 16),
              Text(
                _status,
                style: Theme.of(context).textTheme.subtitle1,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _stopTracking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Stop Tracking'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
