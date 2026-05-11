import type { ActivityRecord } from '../types';

type UploadedMedia = {
  url: string;
};

type SaveRecordWithMediaDeps = {
  createRecord: (record: Omit<ActivityRecord, 'id'>) => Promise<ActivityRecord>;
  uploadRecord: (petId: string, recordId: string, uri: string) => Promise<UploadedMedia>;
  removeRecord: (petId: string, recordId: string) => Promise<void>;
};

export async function saveRecordWithMedia(
  record: Omit<ActivityRecord, 'id'>,
  deps: SaveRecordWithMediaDeps,
): Promise<ActivityRecord> {
  const created = await deps.createRecord(record);
  const photoUris = record.poopPhotos ?? [];
  if (photoUris.length === 0) return created;

  try {
    const uploadedMedia = await Promise.all(
      photoUris.map((uri) => deps.uploadRecord(record.petId, created.id, uri)),
    );
    return { ...created, poopPhotos: uploadedMedia.map((media) => media.url) };
  } catch (error) {
    await deps.removeRecord(record.petId, created.id).catch(() => undefined);
    throw error;
  }
}
