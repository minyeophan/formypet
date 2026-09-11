class UserProfile {
  final String id;
  final String email;
  final String nickname;
  // profileImageUrl is relative path like /api/v1/media/{id} — PRIVATE endpoint
  final String? profileImageUrl;
  final String? registrationSource;
  final String role;

  bool get isAdmin => role == 'ADMIN';

  const UserProfile({
    required this.id,
    required this.email,
    required this.nickname,
    this.profileImageUrl,
    this.registrationSource,
    this.role = 'USER',
  });

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    id: j['id'].toString(),
    email: j['email'] as String,
    nickname: j['nickname'] as String,
    profileImageUrl: j['profileImageUrl'] as String?,
    registrationSource: j['registrationSource'] as String?,
    role: j['role'] as String? ?? 'USER',
  );
}
