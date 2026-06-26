class CareSchedule {
  final String id;
  final String petId;
  final String categoryId;
  final String title;
  final String startDate;
  final String? startTime;
  final String endDate;
  final String? endTime;
  final bool allDay;
  final String? place;
  final String? memo;
  final String reminder;
  final String createdAt;

  const CareSchedule({
    required this.id,
    required this.petId,
    required this.categoryId,
    required this.title,
    required this.startDate,
    this.startTime,
    required this.endDate,
    this.endTime,
    required this.allDay,
    this.place,
    this.memo,
    required this.reminder,
    required this.createdAt,
  });

  factory CareSchedule.fromJson(Map<String, dynamic> json) => CareSchedule(
    id: json['id'].toString(),
    petId: json['petId'].toString(),
    categoryId: json['categoryId'] as String,
    title: json['title'] as String,
    startDate: json['startDate'] as String,
    startTime: json['startTime'] as String?,
    endDate: json['endDate'] as String,
    endTime: json['endTime'] as String?,
    allDay: json['allDay'] as bool? ?? false,
    place: json['place'] as String?,
    memo: json['memo'] as String?,
    reminder: json['reminder'] as String? ?? '알림 없음',
    createdAt: json['createdAt'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'petId': petId,
    'categoryId': categoryId,
    'title': title,
    'startDate': startDate,
    if (startTime != null) 'startTime': startTime,
    'endDate': endDate,
    if (endTime != null) 'endTime': endTime,
    'allDay': allDay,
    if (place != null) 'place': place,
    if (memo != null) 'memo': memo,
    'reminder': reminder,
    'createdAt': createdAt,
  };

  Map<String, dynamic> toRequestJson() => {
    'categoryId': categoryId,
    'title': title,
    'startDate': startDate,
    if (startTime != null) 'startTime': startTime,
    'endDate': endDate,
    if (endTime != null) 'endTime': endTime,
    'allDay': allDay,
    if (place != null) 'place': place,
    if (memo != null) 'memo': memo,
    'reminder': reminder,
  };
}
