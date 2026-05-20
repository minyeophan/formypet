import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/pet_provider.dart';
import '../../core/pet_colors.dart';
import '../../widgets/app_text.dart';

class MyScreen extends ConsumerWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final petState = ref.watch(petProvider);
    final profile = authState.profile;

    return Scaffold(
      appBar: AppBar(title: const AppText('마이', fontWeight: FontWeight.bold)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile card
          if (profile != null)
            ListTile(
              leading: CircleAvatar(
                child: AppText(
                  profile.nickname.isNotEmpty ? profile.nickname[0] : '?',
                ),
              ),
              title: AppText(profile.nickname, fontWeight: FontWeight.bold),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(profile.email, fontSize: 12),
                  if (profile.registrationSource == 'KAKAO')
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Chip(
                        label: Text('카카오로 로그인됨',
                            style: TextStyle(fontSize: 11, color: Color(0xFF191919))),
                        backgroundColor: Color(0xFFFEE500),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
            ),
          const Divider(),
          // Pet list
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: AppText('내 반려동물', fontWeight: FontWeight.bold),
          ),
          ...petState.pets.map((pet) {
            final color = colorPairForHex(pet.accentColor);
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: color.accent,
                child: AppText(pet.name[0], color: Colors.white),
              ),
              title: AppText(pet.name),
              onTap: () => context.push('/pet/${pet.id}'),
              trailing: const Icon(Icons.chevron_right),
            );
          }),
          ListTile(
            leading: const Icon(Icons.add),
            title: const AppText('반려동물 추가'),
            onTap: () => context.push('/pets/new'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const AppText('로그아웃', color: Colors.red),
            onTap: () async {
              await ref.read(authProvider.notifier).logout();
            },
          ),
        ],
      ),
    );
  }
}
