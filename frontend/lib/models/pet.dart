class Pet {
  final String id;
  final String name;
  final String species;
  final String? birthDate;
  final String? breed;
  final String? adoptionDate;
  final String accentColor;
  final String bgLight;
  final String? gender;
  final double? weight;
  final String? animalRegistrationNumber;
  final bool? neutered;
  final String? specialNotes;
  final String? diseases;
  final String? guardianNickname;
  final String? specialStatus;
  final String? personality;
  final String? primaryHospitalName;
  final String? profileImageUrl;

  const Pet({
    required this.id,
    required this.name,
    required this.species,
    required this.birthDate,
    this.breed,
    this.adoptionDate,
    required this.accentColor,
    required this.bgLight,
    this.gender,
    this.weight,
    this.animalRegistrationNumber,
    this.neutered,
    this.specialNotes,
    this.diseases,
    this.guardianNickname,
    this.specialStatus,
    this.personality,
    this.primaryHospitalName,
    this.profileImageUrl,
  });

  factory Pet.fromJson(Map<String, dynamic> j) => Pet(
    // Backend returns Long id — convert to String
    id: j['id'].toString(),
    name: j['name'] as String,
    species: j['species'] as String,
    birthDate: j['birthDate'] as String?,
    breed: j['breed'] as String?,
    adoptionDate: j['adoptionDate'] as String?,
    accentColor: j['accentColor'] as String? ?? '#FF8A65',
    bgLight: j['bgLight'] as String? ?? '#FFF3E0',
    // gender enum: male | female (lowercase) — may be null
    gender: j['gender'] as String?,
    weight: j['weight'] != null
        ? double.tryParse(j['weight'].toString())
        : null,
    animalRegistrationNumber: j['animalRegistrationNumber'] as String?,
    neutered: j['neutered'] as bool?,
    specialNotes: j['specialNotes'] as String?,
    diseases: j['diseases'] as String?,
    guardianNickname: j['guardianNickname'] as String?,
    specialStatus: j['specialStatus'] as String?,
    personality: j['personality'] as String?,
    primaryHospitalName: j['primaryHospitalName'] as String?,
    profileImageUrl: j['profileImageUrl'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'species': species,
    if (birthDate != null) 'birthDate': birthDate,
    if (breed != null) 'breed': breed,
    if (adoptionDate != null) 'adoptionDate': adoptionDate,
    'accentColor': accentColor,
    'bgLight': bgLight,
    if (gender != null) 'gender': gender,
    if (weight != null) 'weight': weight,
    if (animalRegistrationNumber != null)
      'animalRegistrationNumber': animalRegistrationNumber,
    if (neutered != null) 'neutered': neutered,
    if (specialNotes != null) 'specialNotes': specialNotes,
    if (diseases != null) 'diseases': diseases,
    if (guardianNickname != null) 'guardianNickname': guardianNickname,
    if (specialStatus != null) 'specialStatus': specialStatus,
    if (personality != null) 'personality': personality,
    if (primaryHospitalName != null) 'primaryHospitalName': primaryHospitalName,
    if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
  };

  Pet copyWith({
    String? name,
    String? species,
    String? birthDate,
    String? breed,
    String? adoptionDate,
    String? accentColor,
    String? bgLight,
    String? gender,
    double? weight,
    String? animalRegistrationNumber,
    bool? neutered,
    String? specialNotes,
    String? diseases,
    String? guardianNickname,
    String? specialStatus,
    String? personality,
    String? primaryHospitalName,
    String? profileImageUrl,
  }) => Pet(
    id: id,
    name: name ?? this.name,
    species: species ?? this.species,
    birthDate: birthDate ?? this.birthDate,
    breed: breed ?? this.breed,
    adoptionDate: adoptionDate ?? this.adoptionDate,
    accentColor: accentColor ?? this.accentColor,
    bgLight: bgLight ?? this.bgLight,
    gender: gender ?? this.gender,
    weight: weight ?? this.weight,
    animalRegistrationNumber:
        animalRegistrationNumber ?? this.animalRegistrationNumber,
    neutered: neutered ?? this.neutered,
    specialNotes: specialNotes ?? this.specialNotes,
    diseases: diseases ?? this.diseases,
    guardianNickname: guardianNickname ?? this.guardianNickname,
    specialStatus: specialStatus ?? this.specialStatus,
    personality: personality ?? this.personality,
    primaryHospitalName: primaryHospitalName ?? this.primaryHospitalName,
    profileImageUrl: profileImageUrl ?? this.profileImageUrl,
  );
}
