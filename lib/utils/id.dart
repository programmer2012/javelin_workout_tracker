/// Generates ids that are unique within a session. Used to give exercises and
/// sets a stable identity so widget state survives rebuilds and so renaming an
/// exercise does not detach it from its history.
int _counter = 0;

String newId() {
  _counter++;
  return '${DateTime.now().microsecondsSinceEpoch}_$_counter';
}
