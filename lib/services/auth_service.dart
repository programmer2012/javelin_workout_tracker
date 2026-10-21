import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// The exercises a new account starts with.
  static List<Map<String, dynamic>> get _defaultWorkoutList => [
        {"id": 1, "name": "Bench Press"},
        {"id": 2, "name": "Pull Over"},
        {"id": 3, "name": "Squats"},
        {"id": 4, "name": "Cleans"},
        {"id": 5, "name": "Push Ups"},
      ];

  /// Creates the user document, leaving any existing data untouched.
  ///
  /// `merge: true` matters because this also runs for Google sign-in: a user
  /// who taps "sign in with Google" on the register screen while already
  /// having an account must not have their workout and weight history wiped.
  Future<void> _ensureUserDocument({
    required String uid,
    required String? email,
    required String? username,
  }) async {
    final doc = _firestore.collection('users').doc(uid);
    final snapshot = await doc.get();

    await doc.set({
      'uid': uid,
      'email': email,
      'username': username,
      if (!snapshot.exists) 'workoutList': _defaultWorkoutList,
    }, SetOptions(merge: true));
  }

  // sign user up
  Future<String> signUserUp({
    required String username,
    required String email,
    required String password,
    required String passwordConfirm,
  }) async {
    if (username.trim().isEmpty) return 'Please enter a username';
    if (email.trim().isEmpty) return 'Please enter an email address';
    if (password.isEmpty) return 'Please enter a password';
    if (password != passwordConfirm) return 'The passwords do not match';

    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = cred.user?.uid;
      if (uid == null) return 'Sign up failed, please try again';

      await _ensureUserDocument(
        uid: uid,
        email: email.trim(),
        username: username.trim(),
      );
      return 'success';
    } on FirebaseAuthException catch (err) {
      return err.message ?? err.code;
    } catch (err) {
      return err.toString();
    }
  }

  /// Signs in with Google. Returns `null` when the user cancelled the dialog.
  Future<String?> signInWithGoogle() async {
    try {
      // Null when the user dismisses the account picker.
      final GoogleSignInAccount? gUser = await GoogleSignIn().signIn();
      if (gUser == null) return null;

      final gAuth = await gUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );

      final cred = await _auth.signInWithCredential(credential);
      final user = cred.user;
      if (user == null) return 'Sign in failed, please try again';

      await _ensureUserDocument(
        uid: user.uid,
        email: user.email,
        username: user.displayName,
      );

      return 'success';
    } on FirebaseAuthException catch (err) {
      return err.message ?? err.code;
    } catch (err) {
      return err.toString();
    }
  }
}
