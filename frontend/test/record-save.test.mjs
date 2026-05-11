import assert from 'node:assert/strict';
import { saveRecordWithMedia } from '../src/lib/record-save.ts';

const recordDraft = {
  petId: 'pet-1',
  typeId: 'poop',
  date: '2026-05-12',
  poopPhotos: ['file:///first.webp', 'file:///second.webp'],
};

{
  const calls = [];
  const saved = await saveRecordWithMedia(recordDraft, {
    createRecord: async () => ({ ...recordDraft, id: 'record-1' }),
    uploadRecord: async (_petId, _recordId, uri) => {
      calls.push(uri);
      return { url: `https://cdn.local/${calls.length}.webp` };
    },
    removeRecord: async () => {
      throw new Error('remove should not run on success');
    },
  });

  assert.deepEqual(calls, recordDraft.poopPhotos);
  assert.deepEqual(saved.poopPhotos, ['https://cdn.local/1.webp', 'https://cdn.local/2.webp']);
}

{
  const removed = [];
  const failure = new Error('upload failed');

  await assert.rejects(
    () => saveRecordWithMedia(recordDraft, {
      createRecord: async () => ({ ...recordDraft, id: 'record-2' }),
      uploadRecord: async () => {
        throw failure;
      },
      removeRecord: async (petId, recordId) => {
        removed.push([petId, recordId]);
      },
    }),
    failure,
  );

  assert.deepEqual(removed, [['pet-1', 'record-2']]);
}

{
  const saved = await saveRecordWithMedia({ ...recordDraft, poopPhotos: [] }, {
    createRecord: async (record) => ({ ...record, id: 'record-3' }),
    uploadRecord: async () => {
      throw new Error('upload should not run without photos');
    },
    removeRecord: async () => {
      throw new Error('remove should not run without photos');
    },
  });

  assert.equal(saved.id, 'record-3');
  assert.deepEqual(saved.poopPhotos, []);
}
