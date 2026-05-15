class ActivityRecord {
  final String id;
  final String petId;
  final String typeId;
  final String date;
  final String? time;
  final String? routineId;
  final String? note;
  final List<String> mediaUrls;
  final Map<String, dynamic> detail;

  const ActivityRecord({
    required this.id,
    required this.petId,
    required this.typeId,
    required this.date,
    this.time,
    this.routineId,
    this.note,
    this.mediaUrls = const [],
    this.detail = const {},
  });

  factory ActivityRecord.fromJson(Map<String, dynamic> j) {
    // Backend returns Map<String,Object> detail — flatten into typed fields
    final rawDetail = j['detail'] as Map<String, dynamic>? ?? {};
    final detail = <String, dynamic>{};
    rawDetail.forEach((k, v) {
      detail[k] = v;
    });

    // GPS fields: walk (startLng/Lat, endLng/Lat), vet (clinicLng/Lat)
    // These are stored as POINT in DB and serialized as lng/lat fields in detail

    return ActivityRecord(
      id: j['id'].toString(),
      petId: j['petId'].toString(),
      typeId: j['typeId'] as String,
      date: j['date'] as String,
      time: j['time'] as String?,
      routineId: j['routineId'] != null ? j['routineId'].toString() : null,
      note: j['note'] as String?,
      mediaUrls: (j['mediaUrls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      detail: detail,
    );
  }

  Map<String, dynamic> toJson() => {
        'typeId': typeId,
        'date': date,
        if (time != null) 'time': time,
        if (routineId != null) 'routineId': routineId,
        if (note != null) 'note': note,
        if (detail.isNotEmpty) 'detail': detail,
      };
}
