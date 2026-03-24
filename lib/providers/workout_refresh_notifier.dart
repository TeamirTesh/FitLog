import 'package:flutter/foundation.dart';

/// Notifies list screens to reload after a workout is saved (IndexedStack keeps them alive).
class WorkoutRefreshNotifier extends ChangeNotifier {
  void notifyWorkoutsChanged() => notifyListeners();
}
