import 'package:flutter/foundation.dart';

class ReminderTap {
  const ReminderTap(this.sourceId, this.isSchedule, this.identity);
  final String sourceId;
  final bool isSchedule;
  final String identity;
  String get route =>
      isSchedule ? '/routine/schedule/$sourceId' : '/routine/$sourceId';

  static ReminderTap? parse(Map<String, dynamic> data) {
    final id = data['sourceId']?.toString();
    final type = data['type']?.toString();
    if (id == null || int.tryParse(id) == null || int.parse(id) <= 0) {
      return null;
    }
    if (type != 'ROUTINE_REMINDER' && type != 'CARE_SCHEDULE_REMINDER') {
      return null;
    }
    return ReminderTap(
      id,
      type == 'CARE_SCHEDULE_REMINDER',
      data['messageId']?.toString() ?? '$type:$id',
    );
  }
}

/// Only the latest click is retained while authentication is being restored.
class ReminderTapService extends ChangeNotifier {
  static final instance = ReminderTapService();
  ReminderTap? pending;
  int generation = 0;
  final Set<String> _handled = {};

  void receive(Map<String, dynamic> data) {
    final tap = ReminderTap.parse(data);
    if (tap == null ||
        _handled.contains(tap.identity) ||
        pending?.identity == tap.identity) {
      return;
    }
    generation++;
    pending = tap;
    notifyListeners();
  }

  ReminderTap? take() {
    final tap = pending;
    pending = null;
    if (tap != null) {
      _handled.add(tap.identity);
      if (_handled.length > 100) _handled.remove(_handled.first);
    }
    return tap;
  }

  void reset() {
    generation++;
    pending = null;
    _handled.clear();
    notifyListeners();
  }
}
