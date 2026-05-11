type RootRedirectInput = {
  isAuthenticated: boolean;
  hasOnboarded: boolean;
  segments: string[];
};

export function getRootRedirectTarget({
  isAuthenticated,
  hasOnboarded,
  segments,
}: RootRedirectInput): '/auth' | '/onboarding' | '/(tabs)' | null {
  const rootSegment = segments[0];

  if (!isAuthenticated) {
    return rootSegment === 'auth' ? null : '/auth';
  }

  if (!hasOnboarded) {
    return rootSegment === 'onboarding' ? null : '/onboarding';
  }

  return rootSegment === '(tabs)' ? null : '/(tabs)';
}
