import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
// import 'package:javelin_workout_tracker/models/user.dart' as model;

class AuthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // final String username;
  // final String password;
  // final String passwordConfirm;
  // final String email;

  // AuthService(this.username, this.password, this.passwordConfirm, this.email,)

  // sign user up
  Future<String> signUserUp({
    required String username,
    required String email,
    required String password,
    required String passwordConfirm,
  }) async {
    String res = "Some error occurred";
    try {
      if (password == passwordConfirm &&
          password.isNotEmpty &&
          email.isNotEmpty &&
          username.isNotEmpty) {
        // register user
        UserCredential cred = await _auth.createUserWithEmailAndPassword(
            email: email, password: password);

        // StoregeMethods().uploadImageToStorage('profilePics', file, false);

        // add user to database
        await _firestore.collection('users').doc(cred.user!.uid).set({
          'username': username,
          'uid': cred.user!.uid,
          'email': email,
          'workoutList': [
            {"id": 1, "name": "Bench Press", "isSelected": false},
            {"id": 2, "name": "Pull Over", "isSelected": false},
            {"id": 3, "name": "Squats", "isSelected": false},
            {"id": 4, "name": "Cleans", "isSelected": false},
            {"id": 5, "name": "Push Ups", "isSelected": false},
          ],
        });
        res = 'success';
      }
    } catch (err) {
      res = err.toString();
    }
    return res;
  }

  // error message
  // void errorMessage(String message) {
  //   showDialog(
  //     context: context,
  //     builder: (context) {
  //       return AlertDialog(
  //         title: Center(
  //           child: Text(
  //             message,
  //             style: const TextStyle(color: Colors.deepPurple),
  //           ),
  //         ),
  //       );
  //     },
  //   );
  // }

  // Email and Password Sing Up
  // void signUserUp() async {
  //   showDialog(
  //     context: context,
  //     builder: (context) {
  //       return const Center(
  //         child: CircularProgressIndicator(),
  //       );
  //     },
  //   );

  //   // creating the user
  //   try {
  //     // check if passwords are the same
  //     if (password == passwordConfirm) {
  //       UserCredential userCred =
  //           await FirebaseAuth.instance.createUserWithEmailAndPassword(
  //         email: email,
  //         password: password,
  //       );

  //       model.User user = model.User(
  //         email: email,
  //         uid: userCred.user!.uid,
  //         username: username,
  //       );

  //       await _firestore
  //           .collection("users")
  //           .doc(userCred.user!.uid)
  //           .set(user.toJson());
  //     } else {
  //       // show error message, passwords don't match
  //       errorMessage("Passwords don' match!");
  //     }

  //     // pop the loading circle
  //     // ignore: use_build_context_synchronously
  //     Navigator.pop(context);
  //   } on FirebaseAuthException catch (e) {
  //     // pop the loading circle
  //     // ignore: use_build_context_synchronously
  //     Navigator.pop(context);
  //     // Wrong email
  //     errorMessage(e.code);
  //   }
  // }

  // Google Sign In
  Future<String> signInWithGoogle({required bool firstLogin}) async {
    // begin interactive sign in process
    final GoogleSignInAccount? gUser = await GoogleSignIn().signIn();

    // obtain auth deatails from request
    final GoogleSignInAuthentication gAuth = await gUser!.authentication;

    // create a new credential for user
    final credential = GoogleAuthProvider.credential(
      accessToken: gAuth.accessToken,
      idToken: gAuth.idToken,
    );

    // finally, lets sign in
    UserCredential cred =
        await FirebaseAuth.instance.signInWithCredential(credential);

    if (firstLogin) {
      await _firestore.collection('users').doc(cred.user!.uid).set({
        'username': cred.user!.displayName,
        'uid': cred.user!.uid,
        'email': cred.user!.email,
        'workoutList': [
          {"id": 1, "name": "Bench Press", "isSelected": false},
          {"id": 2, "name": "Pull Over", "isSelected": false},
          {"id": 3, "name": "Squats", "isSelected": false},
          {"id": 4, "name": "Cleans", "isSelected": false},
          {"id": 5, "name": "Push Ups", "isSelected": false},
        ]
      });
    }

    return 'User logged in with Google Auth';
  }
}
