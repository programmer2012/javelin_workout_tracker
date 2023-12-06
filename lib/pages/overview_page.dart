import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:javelin_workout_tracker/components/line_chart_widget.dart';
import 'package:javelin_workout_tracker/services/storage_methods.dart';
import 'package:javelin_workout_tracker/utils/utils.dart';

class OverviewPage extends StatefulWidget {
  final Map<dynamic, dynamic> userData;
  const OverviewPage({required this.userData, super.key});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Uint8List? _image;

  void selectImage() async {
    Uint8List img = await pickImage(ImageSource.gallery);
    setState(() {
      _image = img;
    });
    String photoUrl = await StoregeMethods()
        .uploadImageToStorage('profilePics', _image!, false);
    await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
      'photoUrl': photoUrl,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Column(
            children: [
              // Introduction Container
              Container(
                decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(8))),
                // color: Colors.white,
                height: 100,
                margin: const EdgeInsets.symmetric(
                  vertical: 20,
                ),
                // padding:
                // const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      child: Stack(children: [
                        widget.userData['photoUrl'] != null
                            ? CircleAvatar(
                                radius: 40,
                                backgroundColor: Colors.deepPurple,
                                backgroundImage:
                                    NetworkImage(widget.userData['photoUrl']),
                              )
                            : const CircleAvatar(
                                radius: 40,
                                backgroundColor: Colors.deepPurple,
                                child: Icon(
                                  Icons.person,
                                  size: 40,
                                  color: Colors.black,
                                ),
                              ),
                        Positioned(
                            bottom: -10,
                            left: 45,
                            child: IconButton(
                                onPressed: selectImage,
                                icon: const Icon(
                                  Icons.add_a_photo,
                                  color: Colors.black,
                                  size: 15,
                                )))
                      ]),
                    ),
                    Container(
                        margin: const EdgeInsets.symmetric(
                            vertical: 30, horizontal: 50),
                        child: Text(
                          widget.userData['username'],
                          style: GoogleFonts.kdamThmorPro(
                              textStyle: const TextStyle(fontSize: 20)),
                        ))
                  ],
                ),
              ),

              // Statistics Container
              Container(
                  decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.all(Radius.circular(8))),
                  height: 100,
                  margin: const EdgeInsets.symmetric(vertical: 20),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(0, 0, 0, 10),
                        child: Text(
                          'Statistics',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Moved Weights'),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                child: Text('1000'),
                                width: 40,
                              ),
                              Container(
                                child: Text('kg'),
                                width: 20,
                              )
                            ],
                          )
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Countet Reps'),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                child: Text('1000'),
                                width: 40,
                              ),
                              Container(
                                width: 20,
                              )
                            ],
                          ),
                        ],
                      )
                    ],
                  )),

              // Progression Container
              Container(
                decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(8))),
                height: 300,
                margin: const EdgeInsets.symmetric(vertical: 20),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: const LineChartSample1(),
              ),

              // TBD Container
              Container(
                decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(8))),
                height: 60,
                margin: const EdgeInsets.symmetric(vertical: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
