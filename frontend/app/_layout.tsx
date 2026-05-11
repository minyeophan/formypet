import '../global.css';
import * as SplashScreen from 'expo-splash-screen';
import { NotoSansKR_400Regular, NotoSansKR_700Bold, useFonts } from '@expo-google-fonts/noto-sans-kr';
import { Stack, useRootNavigationState, useRouter, useSegments } from 'expo-router';
import { useEffect } from 'react';
import { View } from 'react-native';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import Toast from 'react-native-toast-message';
import { PetProvider, usePets } from '@/src/lib/pet-context';
import { AuthProvider, useAuth } from '@/src/lib/auth-context';
import RecordModal from '@/src/components/shared/RecordModal';
import { toastConfig } from '@/src/components/shared/AppToast';
import { getRootRedirectTarget } from '@/src/lib/root-redirect';

SplashScreen.preventAutoHideAsync();

function RootLayoutInner() {
  const [loaded, fontError] = useFonts({ NotoSansKR_400Regular, NotoSansKR_700Bold });
  const { isLoading, hasOnboarded } = usePets();
  const { isAuthLoading, isAuthenticated } = useAuth();
  const router = useRouter();
  const rootNavigationState = useRootNavigationState();
  const segments = useSegments();

  const fontsReady = loaded;
  const appReady = fontsReady && !isAuthLoading && !isLoading;

  useEffect(() => {
    if (!appReady || !rootNavigationState?.key) return;
    SplashScreen.hideAsync();
    const target = getRootRedirectTarget({ isAuthenticated, hasOnboarded, segments });
    if (target) router.replace(target);
  }, [appReady, hasOnboarded, isAuthenticated, rootNavigationState?.key, segments]);

  if (!appReady) return <View style={{ flex: 1, backgroundColor: '#F5F3EF' }} />;

  return (
    <>
      <Stack screenOptions={{ headerShown: false }} />
      <RecordModal />
    </>
  );
}

export default function RootLayout() {
  return (
    <AuthProvider>
      <PetProvider>
        <GestureHandlerRootView style={{ flex: 1 }}>
          <SafeAreaProvider>
            <RootLayoutInner />
            <Toast config={toastConfig} />
          </SafeAreaProvider>
        </GestureHandlerRootView>
      </PetProvider>
    </AuthProvider>
  );
}
