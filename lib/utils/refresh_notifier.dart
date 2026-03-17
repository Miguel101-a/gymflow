import 'package:flutter/foundation.dart';

class RefreshNotifier {
  static final ValueNotifier<int> adminRefresh = ValueNotifier<int>(0);
  static final ValueNotifier<int> clientRefresh = ValueNotifier<int>(0);

  static void notifyAdmin() {
    adminRefresh.value++;
  }

  static void notifyClient() {
    clientRefresh.value++;
  }
}
