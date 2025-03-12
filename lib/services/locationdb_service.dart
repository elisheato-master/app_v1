import 'package:mongo_dart/mongo_dart.dart';
import '../models/location_model.dart';

class LocationDbService {
  static LocationDbService? _instance;
  Db? _db;
  String? _groupName;
  String? _userName;
  bool _isInitialized = false;

  // Singleton pattern
  LocationDbService._();

  static LocationDbService get instance {
    _instance ??= LocationDbService._();
    return _instance!;
  }

  Future<void> initialize({
    required String connectionString,
    required String groupName,
    required String userName,
  }) async {
    if (_isInitialized) return;

    try {
      _groupName = groupName;
      _userName = userName;
      
      _db = await Db.create(connectionString);
      await _db!.open();
      
      _isInitialized = true;
      print('MongoDB connection initialized for group: $_groupName, user: $_userName');
    } catch (e) {
      print('Error initializing MongoDB connection: $e');
      throw Exception('Failed to initialize MongoDB: $e');
    }
  }

  Future<void> saveLocation(LocationModel location) async {
    if (!_isInitialized || _db == null) {
      throw Exception('MongoDB connection not initialized');
    }

    try {
      final collection = _db!.collection(_userName!);
      await collection.insert(location.toJson());
      print('Location saved successfully to MongoDB');
    } catch (e) {
      print('Error saving location to MongoDB: $e');
      throw Exception('Failed to save location: $e');
    }
  }

  Future<List<LocationModel>> getLocations() async {
    if (!_isInitialized || _db == null) {
      throw Exception('MongoDB connection not initialized');
    }

    try {
      final collection = _db!.collection(_userName!);
      final results = await collection.find().toList();
      return results.map((doc) => LocationModel.fromJson(doc)).toList();
    } catch (e) {
      print('Error retrieving locations from MongoDB: $e');
      throw Exception('Failed to retrieve locations: $e');
    }
  }

  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _isInitialized = false;
      print('MongoDB connection closed');
    }
  }
}
