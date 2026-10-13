import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/pet_log.dart';
import 'package:frontend/services/pet_log_export_source.dart';

PetLog _log(String id, List<PetLogPhoto> photos) => PetLog(
  id: id,
  petId: 'pet-1',
  date: '2026-10-01',
  time: '12:00:00',
  photos: photos,
  version: 1,
);

PetLogPhoto _photo(String id, int position) => PetLogPhoto(
  id: id,
  url: 'https://example.test/$id.jpg',
  position: position,
  width: 800,
  height: 600,
);

void main() {
  group('PetLogExportSource', () {
    test('free and future premium photo limits are explicit', () {
      expect(PetLogExportPhotoLimit.forMembership(isPremium: false), 5);
      expect(PetLogExportPhotoLimit.forMembership(isPremium: true), 20);
    });

    test('selection caps additions and keeps a manually reordered list', () {
      final selection = PetLogExportSelection(limit: 5);
      for (var index = 0; index < 5; index++) {
        expect(selection.add('photo-$index'), isTrue);
      }
      expect(selection.add('photo-5'), isFalse);

      selection.reorder(0, 3);
      expect(selection.ids, [
        'photo-1',
        'photo-2',
        'photo-3',
        'photo-0',
        'photo-4',
      ]);

      selection.remove('photo-2');
      expect(selection.ids, ['photo-1', 'photo-3', 'photo-0', 'photo-4']);
      expect(selection.add('photo-5'), isTrue);
    });

    test('uses the final index reported by onReorderItem', () {
      final selection = PetLogExportSelection(limit: 5);
      for (final id in ['a', 'b', 'c', 'd']) {
        selection.add(id);
      }

      // Flutter's onReorderItem already adjusts the destination after removal.
      selection.reorder(0, 2);

      expect(selection.ids, ['b', 'c', 'a', 'd']);
    });

    test(
      'flattens pages in record order and photos in stored position order',
      () {
        final result = flattenPetLogExportPhotos([
          _log('newer', [_photo('newer-2', 2), _photo('newer-1', 1)]),
          _log('older', [_photo('older-1', 1)]),
        ]);

        expect(result.map((item) => item.photo.id), [
          'newer-1',
          'newer-2',
          'older-1',
        ]);
        expect(result.map((item) => item.logDate), [
          '2026-10-01',
          '2026-10-01',
          '2026-10-01',
        ]);
      },
    );

    test('accumulates one page at a time and retains page order', () {
      final accumulator = PetLogExportPageAccumulator();
      accumulator.append(
        PetLogPage(
          items: [
            _log('newer', [_photo('a', 1)]),
          ],
          years: const [2026],
          hasAny: true,
          nextCursor: 'page-2',
        ),
      );
      expect(accumulator.photos.map((item) => item.photo.id), ['a']);
      expect(accumulator.nextCursor, 'page-2');

      accumulator.append(
        PetLogPage(
          items: [
            _log('older', [_photo('b', 1)]),
          ],
          years: const [2026],
          hasAny: true,
        ),
      );
      expect(accumulator.photos.map((item) => item.photo.id), ['a', 'b']);
      expect(accumulator.nextCursor, isNull);
    });

    test('deduplicates photos and stops on a repeated page cursor', () {
      final accumulator = PetLogExportPageAccumulator();
      PetLogPage page({String? next}) => PetLogPage(
        items: [
          _log('one', [_photo('same-photo', 1)]),
        ],
        years: const [2026],
        hasAny: true,
        nextCursor: next,
      );
      accumulator.append(page(next: 'page-2'));
      expect(() => accumulator.append(page(next: 'page-2')), throwsStateError);
      expect(accumulator.nextCursor, isNull);
      expect(accumulator.photos, hasLength(1));
    });

    test('reset clears the list and its cursor history', () {
      final accumulator = PetLogExportPageAccumulator();
      accumulator.append(
        PetLogPage(
          items: [
            _log('newer', [_photo('a', 1)]),
          ],
          years: const [2026],
          hasAny: true,
          nextCursor: 'page-2',
        ),
      );
      accumulator.reset();
      expect(accumulator.photos, isEmpty);
      expect(accumulator.nextCursor, isNull);
      accumulator.append(
        PetLogPage(
          items: [
            _log('newer', [_photo('a', 1)]),
          ],
          years: const [2026],
          hasAny: true,
          nextCursor: 'page-2',
        ),
      );
      expect(accumulator.nextCursor, 'page-2');
    });
  });
}
