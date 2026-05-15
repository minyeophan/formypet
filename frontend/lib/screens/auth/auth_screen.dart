import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_text.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _isLogin = true;
  bool _isLoading = false;
  String? _error;

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nicknameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final auth = ref.read(authProvider.notifier);
      if (_isLogin) {
        await auth.login(
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text);
      } else {
        await auth.register(
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
            nickname: _nicknameCtrl.text.trim());
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppText('petyilgi', fontSize: 32, fontWeight: FontWeight.bold),
              const SizedBox(height: 8),
              AppText('반려동물 케어 앱', fontSize: 14, color: Colors.grey),
              const SizedBox(height: 40),
              if (!_isLogin)
                TextField(
                  controller: _nicknameCtrl,
                  decoration: const InputDecoration(
                      labelText: '닉네임', border: OutlineInputBorder()),
                ),
              if (!_isLogin) const SizedBox(height: 12),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    labelText: '이메일', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: '비밀번호', border: OutlineInputBorder()),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                AppText(_error!, color: Colors.red, fontSize: 13),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : AppText(_isLogin ? '로그인' : '회원가입',
                          fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => setState(() => _isLogin = !_isLogin),
                child: AppText(
                  _isLogin ? '계정이 없으신가요? 회원가입' : '이미 계정이 있으신가요? 로그인',
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
