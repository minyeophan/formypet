enum CompletionStatus { pending, completed, skipped }

class Routine {
  final String id;
  final String petId;
  final String label;
  final String typeId;
  final String repeatType; // daily | weekly | biweekly | monthly
  final List<String> times; // HH:MM list
  final List<int> days;
  final String? note;
  final String startDate;
  final String? endDate;
  final int monthlyInterval;
  final bool active;
  final bool notificationEnabled;

  const Routine({
    required this.id,
    required this.petId,
    required this.label,
    required this.typeId,
    required this.repeatType,
    required this.times,
    required this.days,
    this.note,
    required this.startDate,
    this.endDate,
    this.monthlyInterval = 1,
    this.active = true,
    this.notificationEnabled = true,
  });

  factory Routine.fromJson(Map<String, dynamic> j) => Routine(
    id: j['id'].toString(),
    petId: j['petId'].toString(),
    label: j['label'] as String,
    typeId: j['typeId'] as String,
    repeatType: j['repeatType'] as String,
    times:
        (j['times'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    days:
        (j['days'] as List<dynamic>?)
            ?.map((e) => int.parse(e.toString()))
            .toList() ??
        [],
    note: j['note'] as String?,
    startDate: j['startDate'] as String,
    endDate: j['endDate'] as String?,
    monthlyInterval: j['monthlyInterval'] as int? ?? 1,
    active: j['active'] as bool? ?? true,
    notificationEnabled: j['notificationEnabled'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'label': label,
    'typeId': typeId,
    'repeatType': repeatType,
    'times': times,
    'days': days,
    'startDate': startDate,
    if (endDate != null) 'endDate': endDate,
    if (note != null) 'note': note,
    'monthlyInterval': monthlyInterval,
    'notificationEnabled': notificationEnabled,
  };
}

class RoutineCompletion {
  final String id;
  final String routineId;
  final String petId;
  final String scheduledDate;
  final CompletionStatus status;
  final String? completedAt;

  const RoutineCompletion({
    required this.id,
    required this.routineId,
    required this.petId,
    required this.scheduledDate,
    required this.status,
    this.completedAt,
  });

  factory RoutineCompletion.fromJson(Map<String, dynamic> j) {
    final rawStatus = (j['status'] as String? ?? 'PENDING').toUpperCase();
    final status = switch (rawStatus) {
      'COMPLETED' => CompletionStatus.completed,
      'SKIPPED' => CompletionStatus.skipped,
      _ => CompletionStatus.pending,
    };
    return RoutineCompletion(
      id: j['id'].toString(),
      routineId: j['routineId'].toString(),
      petId: j['petId'].toString(),
      scheduledDate: j['scheduledDate'] as String,
      status: status,
      completedAt: j['completedAt'] as String?,
    );
  }
}

class TodayRoutineSummary {
  final int total;
  final int done;
  final double rate;

  const TodayRoutineSummary({
    required this.total,
    required this.done,
    required this.rate,
  });

  factory TodayRoutineSummary.fromJson(Map<String, dynamic> j) =>
      TodayRoutineSummary(
        total: j['total'] as int? ?? 0,
        done: j['done'] as int? ?? 0,
        rate: (j['rate'] as num?)?.toDouble() ?? 0.0,
      );
}

// Backend TodayRoutineItem: { routine: RoutineResponse, completion: RoutineCompletionResponse }
class TodayRoutineItem {
  final Routine routine;
  final RoutineCompletion completion;

  const TodayRoutineItem({required this.routine, required this.completion});

  factory TodayRoutineItem.fromJson(Map<String, dynamic> j) => TodayRoutineItem(
    routine: Routine.fromJson(j['routine'] as Map<String, dynamic>),
    completion: RoutineCompletion.fromJson(
      j['completion'] as Map<String, dynamic>,
    ),
  );
}

// Backend TodayRoutineResponse: { routines: List<TodayRoutineItem>, summary: Summary }
class TodayRoutineData {
  final List<TodayRoutineItem> items;
  final TodayRoutineSummary summary;

  const TodayRoutineData({required this.items, required this.summary});
}
