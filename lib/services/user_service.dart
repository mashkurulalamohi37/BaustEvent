import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class UserService {
  static const String _currentUserKey = 'current_user';
  static const String _usersKey = 'users';
  
  // Get current user
  static Future<User?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_currentUserKey);
      if (userJson != null) {
        return User.fromJson(jsonDecode(userJson));
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  // Set current user
  static Future<bool> setCurrentUser(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_currentUserKey, jsonEncode(user.toJson()));
    } catch (e) {
      return false;
    }
  }
  
  // Create user
  static Future<bool> createUser(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final users = await getAllUsers();
      users.add(user);
      
      final usersJson = users.map((u) => jsonEncode(u.toJson())).toList();
      return await prefs.setStringList(_usersKey, usersJson);
    } catch (e) {
      return false;
    }
  }
  
  // Get all users
  static Future<List<User>> getAllUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getStringList(_usersKey) ?? [];
      return usersJson.map((json) => User.fromJson(jsonDecode(json))).toList();
    } catch (e) {
      return [];
    }
  }
  
  // Update user
  static Future<bool> updateUser(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final users = await getAllUsers();
      final index = users.indexWhere((u) => u.id == user.id);
      
      if (index != -1) {
        users[index] = user;
        final usersJson = users.map((u) => jsonEncode(u.toJson())).toList();
        return await prefs.setStringList(_usersKey, usersJson);
      }
      return false;
    } catch (e) {
      return false;
    }
  }
  
  // Sign out
  static Future<bool> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_currentUserKey);
    } catch (e) {
      return false;
    }
  }
  
  // Remove known demo users and clear if currently selected
  static Future<void> removeDemoUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final users = await getAllUsers();
    final filtered = users.where((u) =>
      u.email.toLowerCase() != 'john.doe@baust.edu' &&
      u.email.toLowerCase() != 'sarah.johnson@baust.edu' &&
      u.id != 'user_1' &&
      u.id != 'organizer_1'
    ).toList();

    final usersJson = filtered.map((u) => jsonEncode(u.toJson())).toList();
    await prefs.setStringList(_usersKey, usersJson);

    final current = await getCurrentUser();
    if (current != null && (current.id == 'user_1' || current.id == 'organizer_1')) {
      await prefs.remove(_currentUserKey);
    }
  }
}
