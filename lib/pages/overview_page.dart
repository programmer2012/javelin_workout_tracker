import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:javelin_workout_tracker/components/progress_chart.dart';
import 'package:javelin_workout_tracker/models/progression.dart';
import 'package:javelin_workout_tracker/models/workout.dart';
import 'package:javelin_workout_tracker/pages/coach_page.dart';
import 'package:javelin_workout_tracker/services/storage_methods.dart';
import 'package:javelin_workout_tracker/services/workout_repository.dart';
import 'package:javelin_workout_tracker/utils/utils.dart';

class OverviewPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  /// Supplied by [MainView], which owns the one workouts listener.
  final List<Workout> workouts;

  const OverviewPage({
    required this.userData,
    required this.workouts,
    super.key,
  });

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final WorkoutRepository _repository = WorkoutRepository();
  final TextEditingController _weightController = TextEditingController();

  Uint8List? _image;
  bool _uploadingImage = false;

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  int get _totalReps =>
      widget.workouts.fold(0, (total, w) => total + w.totalReps);

  double get _totalVolume =>
      widget.workouts.fold(0.0, (total, w) => total + w.totalVolume);

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _selectImage() async {
    final picked = await pickImage(ImageSource.gallery);
    // Null when the user closed the picker without choosing anything.
    if (picked == null || !mounted) return;

    setState(() {
      _image = picked.bytes;
      _uploadingImage = true;
    });

    try {
      final photoUrl = await StoregeMethods().uploadImageToStorage(
        'profilePics',
        picked.bytes,
        contentType: picked.contentType,
      );
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .set({'photoUrl': photoUrl}, SetOptions(merge: true));
    } catch (error) {
      // Leave the preview up only if it actually uploaded.
      if (mounted) setState(() => _image = null);
      _showMessage('Could not upload the picture: $error');
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _submitWeight() async {
    FocusScope.of(context).unfocus();

    final weight =
        double.tryParse(_weightController.text.trim().replaceAll(',', '.'));
    if (weight == null || weight <= 0) {
      _showMessage('Please enter a valid weight');
      return;
    }

    try {
      await _repository.addWeightEntry(weight);
      _weightController.clear();
    } catch (error) {
      _showMessage('Could not save the weight: $error');
    }
  }

  String get _username {
    final name = widget.userData['username']?.toString();
    return (name == null || name.isEmpty) ? 'Athlete' : name;
  }

  String? get _photoUrl {
    final url = widget.userData['photoUrl']?.toString();
    return (url == null || url.isEmpty) ? null : url;
  }

  /// Read straight from the live user document, so a logged weight shows up in
  /// the chart as soon as the write lands.
  List<ChartPoint> get _weightPoints =>
      weightPoints(_repository.weightHistoryFrom(widget.userData));

  String get _latestWeightLabel {
    final points = _weightPoints;
    if (points.isEmpty) return 'No entry yet';
    final latest = points.last;
    return 'Last: ${_formatNumber(latest.value)} kg '
        '(${latest.date.day}.${latest.date.month}.)';
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
              _buildProfileCard(),
              _buildStatisticsCard(),
              _buildWeightTrackerCard(),
              _buildProgressionCard(),
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                height: 60,
                margin: const EdgeInsets.symmetric(vertical: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    final photoUrl = _photoUrl;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      height: 100,
      margin: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.deepPurple,
                  backgroundImage: _image != null
                      ? MemoryImage(_image!)
                      : (photoUrl != null
                          ? NetworkImage(photoUrl) as ImageProvider
                          : null),
                  child: (_image == null && photoUrl == null)
                      ? const Icon(Icons.person,
                          size: 40, color: Colors.black)
                      : null,
                ),
                Positioned(
                  bottom: -10,
                  left: 45,
                  child: IconButton(
                    onPressed: _uploadingImage ? null : _selectImage,
                    icon: _uploadingImage
                        ? const SizedBox(
                            height: 15,
                            width: 15,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.add_a_photo,
                            color: Colors.black,
                            size: 15,
                          ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                _username,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.kdamThmorPro(
                  textStyle: const TextStyle(fontSize: 20),
                ),
              ),
            ),
          ),
          // The Coach's Zone lost its tab to the training plan, so it is
          // reachable from here instead.
          IconButton(
            tooltip: "Coach's Zone",
            icon: const Icon(Icons.sports, color: Colors.deepPurple),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CoachPage(
                  userData: Map<String, dynamic>.from(widget.userData),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      height: 100,
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(0, 0, 0, 10),
            child: Text(
              'Statistics',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
          _StatRow(
            label: 'Moved Weights',
            value: _formatNumber(_totalVolume),
            unit: '[kg]',
          ),
          _StatRow(
            label: 'Countet Reps',
            value: '$_totalReps',
            unit: '[rps]',
          ),
        ],
      ),
    );
  }

  /// Whole numbers stay whole; anything else gets a single decimal.
  static String _formatNumber(double value) {
    return value == value.roundToDouble()
        ? value.round().toString()
        : value.toStringAsFixed(1);
  }

  Widget _buildWeightTrackerCard() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      height: 80,
      margin: const EdgeInsets.symmetric(vertical: 20),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Weight Tracker'),
                Text(
                  _latestWeightLabel,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
            Row(
              children: [
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    style: const TextStyle(fontSize: 14),
                    textAlign: TextAlign.center,
                    controller: _weightController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onFieldSubmitted: (_) => _submitWeight(),
                    decoration: const InputDecoration(
                      hintText: 'kg',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                      ),
                      contentPadding: EdgeInsets.all(5),
                      isDense: true,
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.fromLTRB(10, 0, 0, 0),
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 85, 183, 58),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    color: Colors.deepPurple,
                    onPressed: _submitWeight,
                    icon: const Icon(
                      Icons.check,
                      color: Color.fromRGBO(255, 255, 255, 1),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressionCard() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      height: 300,
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Body Weight',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ProgressChart(
              points: _weightPoints,
              emptyMessage: 'Log your weight to see your progression here.',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _StatRow({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Row(
          children: [
            SizedBox(width: 60, child: Text(value)),
            SizedBox(width: 40, child: Text(unit)),
          ],
        ),
      ],
    );
  }
}
