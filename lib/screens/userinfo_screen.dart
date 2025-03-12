import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';


class UserInfoScreen extends StatefulWidget {

  final UserModel user;
  
  const UserInfoScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<UserInfoScreen> createState() => _UserInfoScreenState();
}

class _UserInfoScreenState extends State<UserInfoScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _userNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  
  // Method channel to communicate with native Kotlin code
  static const platform = MethodChannel('com.example.app_v1/location');

  @override
  void initState() {
    super.initState();
    _checkExistingUser();
  }

  Future<void> _checkExistingUser() async {
    setState(() => _isLoading = true);
    
    final prefs = await SharedPreferences.getInstance();
    final groupName = prefs.getString('groupName');
    final userName = prefs.getString('userName');
    
    if (groupName != null && userName != null) {
      _startLocationService(groupName, userName);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen(groupName: groupName, userName: userName)),
      );
    }
    
    setState(() => _isLoading = false);
  }
  
  Future<void> _startLocationService(String groupName, String userName) async {
    try {
      await platform.invokeMethod('startLocationService', {
        'groupName': groupName,
        'userName': userName
      });
    } on PlatformException catch (e) {
      debugPrint("Failed to start location service: ${e.message}");
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    final groupName = _groupNameController.text.trim();
    final userName = _userNameController.text.trim();
    
    // Save user data to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('groupName', groupName);
    await prefs.setString('userName', userName);
    
    // Start location service
    await _startLocationService(groupName, userName);
    
    setState(() => _isLoading = false);
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen(groupName: groupName, userName: userName)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Tracker Login'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final authService = Provider.of<AuthService>(context, listen: false);
              await authService.signOut();
              
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
// Login Screen                    
                    if (user.photoUrl != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20.0),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundImage: NetworkImage(user.photoUrl!),
                        ),
                      ),
                    Text(
                      'Welcome${user.displayName != null ? ', ${user.displayName}' : ''}!',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Email: ${user.email}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Signed in with: ${user.authType.toString().split('.').last}',
                      style: const TextStyle(fontSize: 16),
                    ),
//  Group Names
                    TextFormField(
                      controller: _groupNameController,
                      decoration: const InputDecoration(
                        labelText: 'Group Name',
                        hintText: 'Enter group name (used as DB name)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a group name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _userNameController,
                      decoration: const InputDecoration(
                        labelText: 'User Name',
                        hintText: 'Enter your name (used as collection name)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a user name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _handleLogin,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('Start Tracking'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
