import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/location_model.dart';
import 'locationdb_service.dart';

class LocationHandler {
  static const MethodChannel _channel = MethodChannel('com.example.app_v1/location_channel');
  
  static void registerCallbacks() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }
  
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'initializeDatabase':
        final groupName = call.arguments['groupName'];
        final userName = call.arguments['userName'];
        return _initializeDatabase(groupName, userName);
      
      case 'saveLocation':
        return _saveLocation(call.arguments);
      
      default:
        throw PlatformException(code: 'UNSUPPORTED_METHOD', message: 'Method not supported: ${call.method}');
    }
  }

  static Future<void> _initializeDatabase(String groupName, String userName) async {
    try {
      final connectionString = dotenv.env['MONGODB_URI'] ?? 
          throw Exception('MONGODB_URI not found in environment variables');
      
      await LocationDbService.instance.initialize(
        connectionString: connectionString,
        groupName: groupName,
        userName: userName,
      );
    } catch (e) {
      print('Error initializing database: $e');
      throw e;
    }
  }

  static Future<void> _saveLocation(Map<dynamic, dynamic> locationData) async {
    try {
      final location = LocationModel(
        latitude: locationData['latitude'],
        longitude: locationData['longitude'],
        timestamp: locationData['timestamp'],
        accuracy: locationData['accuracy'],
        provider: locationData['provider'],
        verticalAccuracy: locationData['verticalAccuracy'],
      );
      
      await LocationDbService.instance.saveLocation(location);
    } catch (e) {
      print('Error saving location: $e');
      throw e;
    }
  }
  
  // Add this to your app's main.dart to register the background callback
  static void startLocationService() {
    const backgroundCallbackHandle = 
        ui.CallbackHandle.fromRawHandle(0); // Replace with generated callback ID
        
    // Call this from your Flutter code to start the service
    _channel.invokeMethod('startLocationService', {
      'dartCallbackHandle': backgroundCallbackHandle.toRawHandle(),
    });
  }
}
