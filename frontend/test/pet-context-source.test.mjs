import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const petContextSource = readFileSync(new URL('../src/lib/pet-context.tsx', import.meta.url), 'utf8');

assert.ok(
  !petContextSource.includes("AsyncStorage.getItem('hasOnboarded')"),
  'onboarding completion must not be restored from a device-global key',
);
assert.ok(
  !petContextSource.includes("AsyncStorage.setItem('hasOnboarded'"),
  'onboarding completion must not be persisted to a device-global key',
);
