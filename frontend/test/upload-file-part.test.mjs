import assert from 'node:assert/strict';
import { createUploadFilePart, UnsupportedUploadFileTypeError } from '../src/services/upload-file-part.ts';

const contentUriPart = createUploadFilePart({
  uri: 'content://media/external/images/media/12345',
  mimeType: 'image/webp',
});
assert.equal(contentUriPart.name.startsWith('upload-'), true);
assert.equal(contentUriPart.name.endsWith('.webp'), true);
assert.equal(contentUriPart.type, 'image/webp');

const queryPart = createUploadFilePart('file:///tmp/dog%20photo.png?size=large#preview');
assert.equal(queryPart.name, 'dog photo.png');
assert.equal(queryPart.type, 'image/png');

const namedAssetPart = createUploadFilePart({
  uri: 'content://media/external/images/media/67890',
  fileName: 'dog-photo.jpeg',
  mimeType: 'image/jpeg',
});
assert.equal(namedAssetPart.name, 'dog-photo.jpeg');
assert.equal(namedAssetPart.type, 'image/jpeg');

assert.throws(
  () => createUploadFilePart('file:///tmp/photo.gif'),
  UnsupportedUploadFileTypeError,
);

assert.throws(
  () => createUploadFilePart({ uri: 'content://media/external/images/media/99999' }),
  UnsupportedUploadFileTypeError,
);
