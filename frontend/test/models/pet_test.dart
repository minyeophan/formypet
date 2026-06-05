import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/pet.dart';

void main() {
  test('fromJson parses extended profile fields and profileImageUrl', () {
    final pet = Pet.fromJson({
      'id': 1,
      'name': 'Mochi',
      'species': 'dog',
      'birthDate': '2022-03-15',
      'breed': '푸들',
      'adoptionDate': '2023-04-01',
      'accentColor': '#F4A460',
      'bgLight': '#FFF8F0',
      'guardianNickname': '언니',
      'specialStatus': 'senior',
      'personality': '낯가림',
      'primaryHospitalName': '튼튼동물병원',
      'profileImageUrl': '/api/v1/media/10',
    });

    expect(pet.breed, '푸들');
    expect(pet.adoptionDate, '2023-04-01');
    expect(pet.guardianNickname, '언니');
    expect(pet.specialStatus, 'senior');
    expect(pet.personality, '낯가림');
    expect(pet.primaryHospitalName, '튼튼동물병원');
    expect(pet.profileImageUrl, '/api/v1/media/10');
  });

  test('fromJson and toJson preserve nullable birthDate', () {
    final pet = Pet.fromJson({
      'id': 1,
      'name': 'Mochi',
      'species': 'dog',
      'birthDate': null,
      'accentColor': '#F4A460',
      'bgLight': '#FFF8F0',
    });

    expect(pet.birthDate, isNull);
    expect(pet.toJson(), isNot(contains('birthDate')));
  });

  test('toJson and copyWith preserve extended fields', () {
    const pet = Pet(
      id: '1',
      name: 'Mochi',
      species: 'dog',
      birthDate: '2022-03-15',
      breed: '푸들',
      adoptionDate: '2023-04-01',
      accentColor: '#F4A460',
      bgLight: '#FFF8F0',
      gender: 'female',
      weight: 4.2,
      animalRegistrationNumber: '410000000000001',
      neutered: true,
      specialNotes: '닭고기 알러지',
      diseases: '슬개골',
      guardianNickname: '언니',
      specialStatus: 'senior',
      personality: '낯가림',
      primaryHospitalName: '튼튼동물병원',
    );

    expect(pet.toJson(), containsPair('breed', '푸들'));
    expect(pet.toJson(), containsPair('adoptionDate', '2023-04-01'));
    expect(pet.toJson(), containsPair('guardianNickname', '언니'));
    expect(pet.toJson(), containsPair('specialStatus', 'senior'));
    expect(pet.toJson(), containsPair('personality', '낯가림'));
    expect(pet.toJson(), containsPair('primaryHospitalName', '튼튼동물병원'));

    final copied = pet.copyWith(profileImageUrl: '/api/v1/media/10');

    expect(copied.birthDate, pet.birthDate);
    expect(copied.breed, pet.breed);
    expect(copied.adoptionDate, pet.adoptionDate);
    expect(copied.animalRegistrationNumber, pet.animalRegistrationNumber);
    expect(copied.neutered, pet.neutered);
    expect(copied.specialNotes, pet.specialNotes);
    expect(copied.diseases, pet.diseases);
    expect(copied.guardianNickname, pet.guardianNickname);
    expect(copied.specialStatus, pet.specialStatus);
    expect(copied.personality, pet.personality);
    expect(copied.primaryHospitalName, pet.primaryHospitalName);
    expect(copied.profileImageUrl, '/api/v1/media/10');
  });
}
