const SUPPORTED_IMAGE_EXTENSIONS = new Set(['jpg', 'jpeg', 'png', 'webp']);
const MIME_TO_EXTENSION: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/jpg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
};

export type UploadAsset = {
  uri: string;
  fileName?: string | null;
  mimeType?: string | null;
};

export type UploadFilePart = {
  uri: string;
  name: string;
  type: string;
};

export class UnsupportedUploadFileTypeError extends Error {
  constructor() {
    super('지원하는 이미지 형식은 jpg, png, webp예요.');
  }
}

export function createUploadFilePart(assetOrUri: UploadAsset | string): UploadFilePart {
  const asset = typeof assetOrUri === 'string' ? { uri: assetOrUri } : assetOrUri;
  const mimeType = asset.mimeType?.toLowerCase() ?? null;
  const nameFromAsset = asset.fileName ? decodeFileName(asset.fileName) : null;
  const nameFromUri = fileNameFromUri(asset.uri);
  const candidateName = nameFromAsset || nameFromUri;
  const extensionFromName = candidateName?.includes('.') ? candidateName.split('.').pop()?.toLowerCase() : undefined;
  const extensionFromMime = mimeType ? MIME_TO_EXTENSION[mimeType] : undefined;
  const extension = extensionFromName && SUPPORTED_IMAGE_EXTENSIONS.has(extensionFromName)
    ? extensionFromName
    : extensionFromMime;

  if (!extension || !SUPPORTED_IMAGE_EXTENSIONS.has(extension)) {
    throw new UnsupportedUploadFileTypeError();
  }

  return {
    uri: asset.uri,
    name: candidateName && extensionFromName === extension ? candidateName : `upload-${Date.now()}.${extension}`,
    type: contentTypeForExtension(extension),
  };
}

function fileNameFromUri(uri: string): string | null {
  const cleanUri = uri.split(/[?#]/, 1)[0] ?? uri;
  const rawName = cleanUri.split('/').pop() ?? '';
  if (!rawName || !rawName.includes('.')) return null;
  return decodeFileName(rawName);
}

function decodeFileName(name: string): string {
  try {
    return decodeURIComponent(name);
  } catch {
    return name;
  }
}

function contentTypeForExtension(extension: string): string {
  if (extension === 'png') return 'image/png';
  if (extension === 'webp') return 'image/webp';
  return 'image/jpeg';
}
