import 'package:flutter/foundation.dart';

/// Index of the selected bottom-navigation tab. Lets any screen jump to
/// another tab (for example "See all" on the dashboard).
class NavProvider extends ChangeNotifier {
  int index = 0;

  static const home = 0;
  static const explore = 1;
  static const reservations = 2;
  static const impact = 3;
  static const profile = 4;

  void go(int i) {
    if (i == index) return;
    index = i;
    notifyListeners();
  }
}
