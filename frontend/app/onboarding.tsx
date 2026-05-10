import { Redirect, router } from 'expo-router';
import { usePets } from '@/src/lib/pet-context';
import PetRegisterForm from '@/src/components/onboarding/PetRegisterForm';

export default function OnboardingScreen() {
  const { hasOnboarded } = usePets();

  if (hasOnboarded) return <Redirect href="/(tabs)" />;

  return <PetRegisterForm onComplete={() => router.replace('/(tabs)')} />;
}
