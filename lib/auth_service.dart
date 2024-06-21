import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AuthService() {
    _firebaseAuth.setPersistence(Persistence.LOCAL);
  }

  Future<UserCredential> signIn(String email, String password) async {
    try {
      email = email.toLowerCase(); // Normalize email
      // Fetch the user by email
      QuerySnapshot querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        DocumentSnapshot userDoc = querySnapshot.docs.first;
        Map<String, dynamic>? userData =
            userDoc.data() as Map<String, dynamic>?;
        bool isDisabled = userData?['isDisabled'] ?? false;

        if (isDisabled) {
          throw Exception('Account is disabled.');
        }

        // Check for cooldown
        int failedLoginAttempts = userData?['failedLoginAttempts'] ?? 0;
        Timestamp? lastFailedLoginAttempt = userData?['lastFailedLoginAttempt'];

        if (failedLoginAttempts >= 3) {
          if (lastFailedLoginAttempt != null) {
            DateTime lastAttemptTime = lastFailedLoginAttempt.toDate();
            DateTime currentTime = DateTime.now();
            Duration cooldownDuration = Duration(seconds: 30);

            if (currentTime.difference(lastAttemptTime) < cooldownDuration) {
              throw Exception('Too many attempts. Please wait 30 seconds.');
            } else {
              // Reset failed attempts after cooldown
              await _firestore.collection('users').doc(userDoc.id).update({
                'failedLoginAttempts': 0,
                'lastFailedLoginAttempt': null,
              });
              failedLoginAttempts = 0;
            }
          }
        }

        // Proceed with sign-in if account is not disabled and no cooldown
        UserCredential userCredential = await _firebaseAuth
            .signInWithEmailAndPassword(email: email, password: password);

        // Reset failed attempts on successful login
        await _firestore.collection('users').doc(userDoc.id).update({
          'failedLoginAttempts': 0,
          'lastFailedLoginAttempt': null,
        });

        return userCredential;
      } else {
        throw Exception('User not found.');
      }
    } catch (e) {
      // Handle failed login attempt
      await _handleFailedLoginAttempt(email);
      throw Exception('Failed to sign in: ${e.toString()}');
    }
  }

  Future<void> _handleFailedLoginAttempt(String email) async {
    email = email.toLowerCase(); // Normalize email
    QuerySnapshot querySnapshot = await _firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      DocumentSnapshot userDoc = querySnapshot.docs.first;
      int failedLoginAttempts =
          (userDoc.data() as Map<String, dynamic>?)?['failedLoginAttempts'] ??
              0;
      failedLoginAttempts += 1;

      await _firestore.collection('users').doc(userDoc.id).update({
        'failedLoginAttempts': failedLoginAttempts,
        'lastFailedLoginAttempt': Timestamp.now(),
      });
    }
  }

  Future<UserCredential> signUp(String email, String password) async {
    email = email.toLowerCase(); // Normalize email
    UserCredential userCredential = await _firebaseAuth
        .createUserWithEmailAndPassword(email: email, password: password);
    await _firestore.collection('users').doc(userCredential.user!.uid).set({
      'email': email,
      'userName': email.split('@')[0], // Default username based on email
      'role': 0, // Default role is 0 for non-admin
      'isDisabled': false, // Initially set account as not disabled
      'failedLoginAttempts': 0, // Initialize failed login attempts
      'lastFailedLoginAttempt': null, // Initialize last failed login attempt
    });
    return userCredential;
  }

  Future<bool> checkUserExists(String email) async {
    try {
      email = email.toLowerCase(); // Normalize email
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

  Future<bool> isAdmin() async {
    User? user = _firebaseAuth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        return data['role'] == 1;
      }
    }
    return false;
  }

  Future<void> disableAccount(String userId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .update({'isDisabled': true});
  }

  Future<void> enableAccount(String userId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .update({'isDisabled': false});
  }

  Future<bool> isAccountDisabled(String userId) async {
    DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(userId).get();
    if (userDoc.exists) {
      Map<String, dynamic>? data = userDoc.data() as Map<String, dynamic>?;
      return data?['isDisabled'] ?? false;
    }
    return false;
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }
}
