import '../core/api_client.dart';
import '../models/pet.dart';

class PetService {
  Future<List<Pet>> getPets() async {
    final res = await dio.get('/api/v1/pets');
    final list = unwrap(res) as List<dynamic>;
    return list.map((e) => Pet.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Pet> createPet(Map<String, dynamic> body) async {
    final res = await dio.post('/api/v1/pets', data: body);
    return Pet.fromJson(unwrap(res) as Map<String, dynamic>);
  }

  Future<Pet> updatePet(String petId, Map<String, dynamic> body) async {
    final res = await dio.put('/api/v1/pets/$petId', data: body);
    return Pet.fromJson(unwrap(res) as Map<String, dynamic>);
  }

  Future<void> deletePet(String petId) async {
    await dio.delete('/api/v1/pets/$petId');
  }
}
