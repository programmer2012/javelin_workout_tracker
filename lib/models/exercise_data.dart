class ExerciseWidgetData {
  final String name;
  final int index;
  final List<dynamic> setWidgetList;
  // Add other properties as needed

  ExerciseWidgetData({
    required this.setWidgetList,
    required this.name,
    required this.index,
    // Initialize other properties here
  });

  // Convert ExerciseWidgetData to a Map
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'index': index,
      'setWidgetList': setWidgetList,
      // Add other properties as needed
    };
  }

  // Create ExerciseWidgetData instance from a Map
  factory ExerciseWidgetData.fromMap(Map<String, dynamic> map) {
    return ExerciseWidgetData(
        name: map['name'],
        index: map['index'],
        setWidgetList: map['setWidgetList']
        // Initialize other properties here
        );
  }
}
