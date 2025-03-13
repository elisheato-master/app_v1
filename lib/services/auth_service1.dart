import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'dart:convert';
import '../models/user_model.dart';
import 'database_service.dart';

class AuthService extends ChangeNotifier {
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final DatabaseService _databaseService = DatabaseService();
  final _secureStorage = const FlutterSecureStorage();
  
  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  // Check if user is logged in
  Future<UserModel?> checkCurrentUser() async {
      try {
        final String? userJson = await _secureStorage.read(key: 'current_user');
        
        if (userJson != null) {
          final Map<String, dynamic> userMap = json.decode(userJson);
          _currentUser = UserModel.fromMap(userMap);
          return _currentUser;
        }
      } catch (e) {
        print('Error retrieving user data: $e');
      }
      return null;
  }  

// Modified: Save current user to secure storage
  Future<void> _saveUserToPrefs(UserModel user) async {
    try {
      await _secureStorage.write(
        key: 'current_user', 
        value: json.encode(user.toMap())
      );
      _currentUser = user;
      notifyListeners();
    } catch (e) {
      print('Error saving user data: $e');
      rethrow;
    }
  }  
  
  // Save current user to SharedPreferences
  Future<void> _saveUserToPrefs(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_user', json.encode(user.toMap()));
    _currentUser = user;
    notifyListeners();
  }
  
  // Sign up with email and password
  Future<UserModel?> signUpWithEmail(String email, String password) async {
    try {
      // Hash the password
      final hashedPassword = _hashPassword(password);
      
      // Create a user in MongoDB
      final userId = DateTime.now().millisecondsSinceEpoch.toString();
      final user = UserModel(
        id: userId,
        email: email,
        authType: AuthType.email,
      );
      
      // Store user in MongoDB
      await _databaseService.createUser(user, hashedPassword);
      
      // Save user to preferences
      await _saveUserToPrefs(user);
      
      return user;
    } catch (e) {
      print('Error signing up with email: $e');
      rethrow;
    }
  }
  
  // Sign in with email and password
  Future<UserModel?> signInWithEmail(String email, String password) async {
    try {
      // Hash the password for comparison
      final hashedPassword = _hashPassword(password);
      
      // Verify credentials against MongoDB
      final user = await _databaseService.getUserByEmail(email);
      
      if (user == null) {
        throw Exception('User not found');
      }
      
      // Verify password
      final isValid = await _databaseService.verifyPassword(email, hashedPassword);
      
      if (!isValid) {
        throw Exception('Invalid password');
      }
      
      // Save user to preferences
      await _saveUserToPrefs(user);
      
      return user;
    } catch (e) {
      print('Error signing in with email: $e');
      rethrow;
    }
  }
  
  // Sign in with Google
  Future<UserModel?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        return null;
      }
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // Get user info
      final userData = {
        'id': googleUser.id,
        'email': googleUser.email,
        'displayName': googleUser.displayName,
        'photoUrl': googleUser.photoUrl,
      };
      
      // Verify token with Google (optional but recommended)
      final validToken = await _verifyGoogleToken(googleAuth.idToken!);
      
      if (!validToken) {
        throw Exception('Invalid Google token');
      }
      
      final userModel = UserModel(
        id: userData['id']!,
        email: userData['email']!,
        displayName: userData['displayName'],
        photoUrl: userData['photoUrl'],
        authType: AuthType.google,
      );
      
      // Store or update user in MongoDB
      await _databaseService.createOrUpdateUser(userModel);
      
      // Save user to preferences
      await _saveUserToPrefs(userModel);
      
      return userModel;
    } catch (e) {
      print('Error signing in with Google: $e');
      rethrow;
    }
  }
  
  // Sign in with Facebook
  Future<UserModel?> signInWithFacebook() async {
    try {
      final LoginResult result = await FacebookAuth.instance.login();
      
      if (result.status == LoginStatus.success) {
        // Get user data from Facebook
        final userData = await FacebookAuth.instance.getUserData();
        
        // Get access token for verification
        final AccessToken accessToken = result.accessToken!;
        
        // Verify token with Facebook (optional but recommended)
        final validToken = await _verifyFacebookToken(accessToken.token);
        
        if (!validToken) {
          throw Exception('Invalid Facebook token');
        }
        
        final userModel = UserModel(
          id: userData['id'],
          email: userData['email'] ?? '${userData['id']}@facebook.com',  // Some FB users don't have email
          displayName: userData['name'],
          photoUrl: userData['picture']['data']['url'],
          authType: AuthType.facebook,
        );
        
        // Store or update user in MongoDB
        await _databaseService.createOrUpdateUser(userModel);
        
        // Save user to preferences
        await _saveUserToPrefs(userModel);
        
        return userModel;
      }
      
      return null;
    } catch (e) {
      print('Error signing in with Facebook: $e');
      rethrow;
    }
  }
  
  // Sign out
  Future<void> signOut() async {
    try {
      // Sign out from providers
      if (_currentUser?.authType == AuthType.google) {
        await _googleSignIn.signOut();
      } else if (_currentUser?.authType == AuthType.facebook) {
        await FacebookAuth.instance.logOut();
      }
      
      // Clear local user data
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_user');
      await _secureStorage.delete(key: 'current_user');
      
      _currentUser = null;
      notifyListeners();
    } catch (e) {
      print('Error signing out: $e');
      rethrow;
    }
  }
  
  // Hash password using SHA-256
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }
}
