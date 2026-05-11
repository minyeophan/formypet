import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const apiSource = readFileSync(new URL('../src/services/api.ts', import.meta.url), 'utf8');

assert.ok(
  !apiSource.includes('new Blob([JSON.stringify(payload)]'),
  'community create payload should not rely on Blob in React Native FormData',
);
assert.ok(
  !apiSource.includes('as unknown as string'),
  'community create payload should not use an unsafe Blob-to-string cast',
);
assert.ok(
  apiSource.includes("form.append('payload', JSON.stringify(payload))"),
  'community create should append JSON payload as a plain FormData field',
);
