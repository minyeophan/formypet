class PetLogPhoto {
  const PetLogPhoto({
    required this.id,
    required this.url,
    required this.position,
    required this.width,
    required this.height,
  });
  final String id, url;
  final int position, width, height;
  factory PetLogPhoto.fromJson(Map<String, dynamic> j) => PetLogPhoto(
    id: '${j['id']}',
    url: j['url'] as String,
    position: j['position'] as int,
    width: j['width'] as int,
    height: j['height'] as int,
  );
}

class PetLog {
  const PetLog({
    required this.id,
    required this.petId,
    required this.date,
    required this.time,
    required this.photos,
    required this.version,
    this.appliedVersion,
    this.note,
  });
  final String id, petId, date, time;
  final List<PetLogPhoto> photos;
  final String? note;
  final int version;
  final int? appliedVersion;
  PetLogPhoto? get cover => photos.isEmpty ? null : photos.first;
  factory PetLog.fromJson(Map<String, dynamic> j) => PetLog(
    id: '${j['id']}',
    petId: '${j['petId']}',
    date: j['date'] as String,
    time: j['time'] as String,
    photos: (j['photos'] as List<dynamic>)
        .map((e) => PetLogPhoto.fromJson(e as Map<String, dynamic>))
        .toList(),
    note: j['note'] as String?,
    version: j['version'] as int,
    appliedVersion: j['appliedVersion'] as int?,
  );
}

class PetLogPage {
  const PetLogPage({
    required this.items,
    required this.years,
    required this.hasAny,
    this.nextCursor,
  });
  final List<PetLog> items;
  final List<int> years;
  final bool hasAny;
  final String? nextCursor;

  factory PetLogPage.fromJson(Map<String, dynamic> json) => PetLogPage(
    items: (json['items'] as List<dynamic>)
        .map((item) => PetLog.fromJson(item as Map<String, dynamic>))
        .toList(),
    years: (json['years'] as List<dynamic>).map((year) => year as int).toList(),
    hasAny: json['hasAny'] as bool,
    nextCursor: json['nextCursor'] as String?,
  );
}
