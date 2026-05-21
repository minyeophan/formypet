import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/pet.dart';

void main() {
  test('fromJson parses profileImageUrl', () {
    final pet = Pet.fromJson({
      'id': 1,
      'name': 'Mochi',
      'species': 'dog',
      'birthDate': '2022-03-15',
      'accentColor': '#F4A460',
      'bgLight': '#FFF8F0',
      'profileImageUrl': '/api/v1/media/10',
    });

    expect(pet.profileImageUrl, '/api/v1/media/10');
  });
}
