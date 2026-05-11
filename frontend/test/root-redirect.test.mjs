import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { getRootRedirectTarget } from '../src/lib/root-redirect.ts';

assert.equal(getRootRedirectTarget({ isAuthenticated: false, hasOnboarded: false, segments: [] }), '/auth');
assert.equal(getRootRedirectTarget({ isAuthenticated: false, hasOnboarded: false, segments: ['auth'] }), null);
assert.equal(getRootRedirectTarget({ isAuthenticated: true, hasOnboarded: false, segments: ['auth'] }), '/onboarding');
assert.equal(getRootRedirectTarget({ isAuthenticated: true, hasOnboarded: false, segments: ['onboarding'] }), null);
assert.equal(getRootRedirectTarget({ isAuthenticated: true, hasOnboarded: true, segments: ['onboarding'] }), '/(tabs)');
assert.equal(getRootRedirectTarget({ isAuthenticated: true, hasOnboarded: true, segments: ['(tabs)'] }), null);
assert.equal(getRootRedirectTarget({ isAuthenticated: true, hasOnboarded: true, segments: ['(tabs)', 'index'] }), null);

const onboardingSource = readFileSync(new URL('../app/onboarding.tsx', import.meta.url), 'utf8');

assert.ok(!/\bRedirect\b/.test(onboardingSource), 'onboarding screen must not render its own Redirect');
assert.ok(!onboardingSource.includes('router.replace('), 'onboarding screen must not call router.replace directly');
