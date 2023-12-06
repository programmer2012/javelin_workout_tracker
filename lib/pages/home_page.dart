import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:javelin_workout_tracker/services/firestore.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // firestore
  final FirestoreService firestoreService = FirestoreService();

  // text controller
  final TextEditingController textController = TextEditingController();

  // get current user from firebase
  final user = FirebaseAuth.instance.currentUser!;

  // opneNoteBox
  void openNoteBox({String? docID}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: TextField(
          controller: textController,
        ),
        actions: [
          // button to save
          ElevatedButton(
            onPressed: () {
              // add a new note
              if (docID == null) {
                firestoreService.addNote(textController.text);
              }

              // update an existing note
              else {
                firestoreService.updateNote(docID, textController.text);
              }
              // clear the text controller
              textController.clear();

              // close the box
              Navigator.pop(context);
            },
            child: const Text('Add'),
          )
        ],
      ),
    );
  }

  // user logout method
  void signUserOut() {
    FirebaseAuth.instance.signOut();
    GoogleSignIn().signOut();
    // AuthService().signOutWithUser();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Notes von'),
            Text(
              user.email!,
              style: TextStyle(fontSize: 10),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: signUserOut,
            icon: const Icon(Icons.logout),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: openNoteBox,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestoreService.getNotesStream(),
        builder: (context, snapshot) {
          // if we have data, get all the docs
          if (snapshot.hasData) {
            List notesList = snapshot.data!.docs;

            // display as a list
            return ListView.builder(
              itemCount: notesList.length,
              itemBuilder: (context, index) {
                // get each individual doc
                DocumentSnapshot document = notesList[index];
                String docID = document.id;

                // get note from each doc
                Map<String, dynamic> data =
                    document.data() as Map<String, dynamic>;
                String noteText = data['note'];

                // display as a list tile
                return ListTile(
                  title: Text(noteText),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => openNoteBox(docID: docID),
                        icon: const Icon(
                          Icons.edit,
                          color: Colors.lightBlue,
                        ),
                      ),
                      IconButton(
                        onPressed: () => firestoreService.deleteNote(docID),
                        icon: const Icon(
                          Icons.delete,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          }

          // if there ist no data retrun nothing
          else {
            return const Text('No notes...');
          }
        },
      ),
    );
  }
}
