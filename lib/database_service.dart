// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addUser(String userId, Map<String, dynamic> userData) async {
    await _firestore.collection('users').doc(userId).set(userData);
  }

  Future<bool> isUsernameTaken(String username) async {
    try {
      // Query the users collection to check if the username already exists
      QuerySnapshot querySnapshot = await _firestore
          .collection('users')
          .where('userName', isEqualTo: username)
          .get();

      // If there are documents returned, it means the username is already taken
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking username availability: $e');
      return false; // Return false in case of any error
    }
  }

  Future<bool> checkUserExists(String email) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking user existence: $e');
      return false;
    }
  }
}
