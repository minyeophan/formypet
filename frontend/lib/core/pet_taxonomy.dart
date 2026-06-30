import 'visuals/app_visual_id.dart';

class PetSpecies {
  final String id;
  final String label;
  final AppVisualId visualId;

  const PetSpecies({
    required this.id,
    required this.label,
    required this.visualId,
  });
}

const List<PetSpecies> kPetSpecies = [
  PetSpecies(id: 'dog', label: '강아지', visualId: AppVisualId.petDog),
  PetSpecies(id: 'cat', label: '고양이', visualId: AppVisualId.petCat),
  PetSpecies(
    id: 'small_animal',
    label: '소동물',
    visualId: AppVisualId.petSmallAnimal,
  ),
  PetSpecies(id: 'bird', label: '조류', visualId: AppVisualId.petBird),
  PetSpecies(id: 'reptile', label: '파충류', visualId: AppVisualId.petReptile),
  PetSpecies(id: 'fish', label: '물고기', visualId: AppVisualId.petFish),
  PetSpecies(id: 'exotic', label: '이색(기타)', visualId: AppVisualId.petExotic),
];

List<String> get kSpeciesList =>
    kPetSpecies.map((species) => species.id).toList();

const String kUnknownBreedLabel = '품종/하위종 몰라요';

const Map<String, List<String>> kBreedOptionsBySpecies = {
  'dog': ['말티즈', '푸들', '포메라니안', '시추', '골든 리트리버', '웰시코기', '믹스견', '기타'],
  'cat': ['코리안 숏헤어', '러시안 블루', '랙돌', '페르시안', '스코티시폴드', '믹스묘', '기타'],
  'small_animal': ['햄스터', '토끼', '기니피그', '고슴도치', '친칠라', '페럿', '데구', '기타'],
  'bird': ['앵무새', '문조', '카나리아', '금화조', '반려닭', '반려오리', '기타'],
  'reptile': ['도마뱀', '거북이', '뱀', '개구리', '이구아나', '기타'],
  'fish': ['구피', '베타', '네온테트라', '금붕어', '디스커스', '해수어', '새우', '기타'],
  'exotic': ['미니피그', '미어캣', '라쿤', '직접 입력'],
};

const List<String> kDiseaseOptions = ['복부', '피부', '관절', '눈', '귀', '직접 입력'];

List<String> breedOptionsForSpecies(String species) => [
  kUnknownBreedLabel,
  ...(kBreedOptionsBySpecies[species] ?? const ['기타']),
];

bool isBreedOptionForSpecies(String species, String? breed) {
  if (breed == null || breed.trim().isEmpty) {
    return true;
  }
  return breedOptionsForSpecies(species).contains(breed.trim());
}

String speciesLabel(String species) => _speciesFor(species)?.label ?? species;

AppVisualId speciesVisualId(String species) {
  final petSpecies = _speciesFor(species);
  if (petSpecies != null) return petSpecies.visualId;

  final normalized = species.toLowerCase();
  if (normalized.contains('cat') || species.contains('고양')) {
    return AppVisualId.petCat;
  }
  if (normalized.contains('small') ||
      normalized.contains('rabbit') ||
      normalized.contains('hamster') ||
      species.contains('토끼') ||
      species.contains('햄스터') ||
      species.contains('소동물')) {
    return AppVisualId.petSmallAnimal;
  }
  if (normalized.contains('bird') ||
      species.contains('새') ||
      species.contains('조류')) {
    return AppVisualId.petBird;
  }
  if (normalized.contains('fish') || species.contains('물고')) {
    return AppVisualId.petFish;
  }
  if (normalized.contains('reptile') || species.contains('파충')) {
    return AppVisualId.petReptile;
  }
  if (normalized.contains('dog') ||
      species.contains('강아') ||
      species.contains('푸들') ||
      species.contains('말티') ||
      species.contains('시추') ||
      species.contains('개')) {
    return AppVisualId.petDog;
  }
  return AppVisualId.petExotic;
}

PetSpecies? _speciesFor(String species) {
  final normalized = species.toLowerCase();
  for (final item in kPetSpecies) {
    if (item.id == normalized) {
      return item;
    }
  }
  return null;
}
