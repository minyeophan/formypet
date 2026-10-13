import '../models/pet_log.dart';

class PetLogExportPhotoLimit {
  const PetLogExportPhotoLimit._();

  static const free = 5;
  static const premium = 20;

  static int forMembership({required bool isPremium}) =>
      isPremium ? premium : free;
}

class PetLogExportPhoto {
  const PetLogExportPhoto({required this.logDate, required this.photo});

  final String logDate;
  final PetLogPhoto photo;
}

class PetLogExportSelection {
  PetLogExportSelection({required this.limit});

  final int limit;
  final List<String> _ids = [];

  List<String> get ids => List.unmodifiable(_ids);
  bool contains(String id) => _ids.contains(id);

  bool add(String id) {
    if (contains(id) || _ids.length >= limit) return false;
    _ids.add(id);
    return true;
  }

  void remove(String id) => _ids.remove(id);

  void clear() => _ids.clear();

  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _ids.length) return;
    if (newIndex < 0 || newIndex >= _ids.length) return;
    final item = _ids.removeAt(oldIndex);
    _ids.insert(newIndex, item);
  }
}

class PetLogExportPageAccumulator {
  final List<PetLogExportPhoto> photos = [];
  final Set<String> _photoIds = {};
  final Set<String> _seenCursors = {};
  String? nextCursor;

  void reset() {
    photos.clear();
    _photoIds.clear();
    _seenCursors.clear();
    nextCursor = null;
  }

  void append(PetLogPage page) {
    final next = page.nextCursor;
    if (next == null || next.isEmpty) {
      nextCursor = null;
    } else if (!_seenCursors.add(next)) {
      nextCursor = null;
      throw StateError('Pet log pagination returned a repeated cursor.');
    } else {
      nextCursor = next;
    }
    for (final item in flattenPetLogExportPhotos(page.items)) {
      if (_photoIds.add(item.photo.id)) photos.add(item);
    }
  }
}

List<PetLogExportPhoto> flattenPetLogExportPhotos(List<PetLog> logs) => [
  for (final log in logs)
    for (final photo
        in (log.photos.toList()
          ..sort((a, b) => a.position.compareTo(b.position))))
      PetLogExportPhoto(logDate: log.date, photo: photo),
];
