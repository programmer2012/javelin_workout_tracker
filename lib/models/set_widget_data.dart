class SetWidgetData {
  final int index;
  final int reps;
  final int weight;

  SetWidgetData({
    required this.index,
    required this.reps,
    required this.weight,
  });

  Map<String, dynamic> toMap() {
    return {
      'index': index,
      'reps': reps,
      'weight': weight,
    };
  }
}
