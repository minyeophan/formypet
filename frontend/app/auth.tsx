import { useState } from 'react';
import { ActivityIndicator, Pressable, TextInput, View } from 'react-native';
import { router } from 'expo-router';
import Toast from 'react-native-toast-message';
import AppText from '@/src/components/shared/AppText';
import { useAuth } from '@/src/lib/auth-context';
import { colors } from '@/src/lib/colors';

export default function AuthScreen() {
  const { login, register } = useAuth();
  const [mode, setMode] = useState<'login' | 'register'>('login');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [nickname, setNickname] = useState('');
  const [submitting, setSubmitting] = useState(false);

  async function submit() {
    if (!email.trim() || !password.trim()) return;
    if (mode === 'register' && !nickname.trim()) return;
    setSubmitting(true);
    try {
      if (mode === 'login') {
        await login({ email: email.trim(), password });
      } else {
        await register({ email: email.trim(), password, nickname: nickname.trim() });
      }
      router.replace('/onboarding');
    } catch (error) {
      Toast.show({ type: 'error', text1: error instanceof Error ? error.message : 'Authentication failed' });
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <View style={{ flex: 1, backgroundColor: '#F5F3EF', paddingHorizontal: 24, justifyContent: 'center' }}>
      <AppText bold style={{ fontSize: 24, color: '#1A1A1A', marginBottom: 8 }}>Petyilgi</AppText>
      <AppText style={{ fontSize: 14, color: '#6B6B6B', marginBottom: 28 }}>
        {mode === 'login' ? 'Login to sync your pets.' : 'Create an account to start syncing.'}
      </AppText>

      <View style={{ flexDirection: 'row', gap: 8, marginBottom: 18 }}>
        {(['login', 'register'] as const).map((item) => (
          <Pressable
            key={item}
            onPress={() => setMode(item)}
            style={{
              flex: 1,
              alignItems: 'center',
              paddingVertical: 10,
              borderRadius: 12,
              backgroundColor: mode === item ? colors.primary : '#FFFFFF',
              borderWidth: 1,
              borderColor: mode === item ? colors.primary : '#E8E4DE',
            }}
          >
            <AppText bold={mode === item} style={{ color: mode === item ? '#FFFFFF' : '#6B6B6B' }}>
              {item === 'login' ? 'Login' : 'Register'}
            </AppText>
          </Pressable>
        ))}
      </View>

      {mode === 'register' && (
        <TextInput
          value={nickname}
          onChangeText={setNickname}
          placeholder="Nickname"
          autoCapitalize="none"
          style={inputStyle}
          placeholderTextColor="#B0A99F"
        />
      )}
      <TextInput
        value={email}
        onChangeText={setEmail}
        placeholder="Email"
        autoCapitalize="none"
        keyboardType="email-address"
        style={inputStyle}
        placeholderTextColor="#B0A99F"
      />
      <TextInput
        value={password}
        onChangeText={setPassword}
        placeholder="Password"
        secureTextEntry
        style={inputStyle}
        placeholderTextColor="#B0A99F"
      />

      <Pressable
        onPress={submit}
        disabled={submitting}
        style={{ backgroundColor: colors.primary, borderRadius: 14, paddingVertical: 14, alignItems: 'center', marginTop: 8 }}
      >
        {submitting ? <ActivityIndicator color="#FFFFFF" /> : <AppText bold style={{ color: '#FFFFFF' }}>{mode === 'login' ? 'Login' : 'Register'}</AppText>}
      </Pressable>
    </View>
  );
}

const inputStyle = {
  backgroundColor: '#FFFFFF',
  borderWidth: 1,
  borderColor: '#E8E4DE',
  borderRadius: 12,
  paddingHorizontal: 16,
  paddingVertical: 12,
  fontSize: 15,
  color: '#1A1A1A',
  marginBottom: 10,
};
