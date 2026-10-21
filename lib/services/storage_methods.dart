import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StoregeMethods {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Uploads [file] to `{childName}/{uid}` and returns its download URL.
  ///
  /// [contentType] is written as metadata rather than left to default. The
  /// storage rules require an `image/*` type, and without it the object is
  /// stored as application/octet-stream and downloads instead of rendering.
  Future<String> uploadImageToStorage(
    String childName,
    Uint8List file, {
    String contentType = 'image/jpeg',
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user');
    }

    final ref = _storage.ref().child(childName).child(user.uid);
    final snapshot = await ref.putData(
      file,
      SettableMetadata(contentType: contentType),
    );
    return snapshot.ref.getDownloadURL();
  }
}
