import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const iconSource = readFileSync(new URL('../src/components/shared/QuickRecordIcon.tsx', import.meta.url), 'utf8');
const quickRecordSource = readFileSync(new URL('../src/components/home/QuickRecord.tsx', import.meta.url), 'utf8');

for (const id of ['meal', 'water', 'walk']) {
  assert.ok(iconSource.includes(`case '${id}':`), `QuickRecordIcon must implement ${id}`);
}

assert.ok(!iconSource.includes("case 'poop':"), 'pilot scope must not implement poop yet');
assert.ok(
  quickRecordSource.includes('<QuickRecordIcon typeId={item.id} fallback={item.emoji}'),
  'QuickRecord must render QuickRecordIcon',
);
