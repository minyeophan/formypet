import AsyncStorage from '@react-native-async-storage/async-storage';
import Constants from 'expo-constants';
import { ActivityRecord, Pet, Post, Routine } from '../types';
import { createUploadFilePart, UploadAsset } from './upload-file-part';

export const API_BASE_URL =
  process.env.EXPO_PUBLIC_API_BASE_URL ??
  (Constants.expoConfig?.extra?.apiBaseUrl as string | undefined) ??
  'http://localhost:8080';

const ACCESS_TOKEN_KEY = 'auth.accessToken';
const REFRESH_TOKEN_KEY = 'auth.refreshToken';

type ApiResponse<T> = {
  data: T;
  message: string;
};

type TokenResponse = {
  accessToken: string;
  refreshToken: string;
};

type BackendPet = Omit<Pet, 'id'> & { id: number };

type BackendRecord = {
  id: number;
  petId: number;
  typeId: string;
  date: string;
  time?: string | null;
  routineId?: number | null;
  note?: string | null;
  mediaUrls?: string[] | null;
  detail?: Record<string, unknown> | null;
};

type BackendRoutine = {
  id: number;
  petId: number;
  label: string;
  typeId: string;
  repeatType: Routine['repeatType'];
  days?: number[] | null;
  monthlyInterval?: number | null;
  startDate: string;
  endDate?: string | null;
  times?: string[] | null;
  note?: string | null;
  detail?: Record<string, unknown> | null;
  active?: boolean;
  notificationEnabled?: boolean | null;
};

type BackendPost = {
  id: number;
  authorNickname: string;
  title: string;
  category: string;
  petSpecies: string;
  content: string;
  likesCount: number;
  commentsCount: number;
  liked: boolean;
  createdAt: string;
  mediaUrls: string[];
  poll?: {
    id: number;
    question: string;
    options: {
      id: number;
      label: string;
      votesCount: number;
      votedByMe: boolean;
    }[];
  } | null;
};

type BackendPostLike = {
  postId: number;
  liked: boolean;
  likesCount: number;
};

type FeedResponse = {
  items: BackendPost[];
  nextCursor: string | null;
};

type RoutineCompletionStatus = 'PENDING' | 'COMPLETED';

type BackendRoutineCompletion = {
  routineId: number;
  scheduledDate: string;
  status: RoutineCompletionStatus;
  completedAt?: string | null;
};

type BackendTodayRoutineResponse = {
  routines: {
    routine: BackendRoutine;
    completion: BackendRoutineCompletion;
  }[];
};

export type UserProfile = {
  email: string;
  nickname: string;
  profileImageUrl?: string | null;
};

export type MediaResponse = {
  id: number;
  url: string;
  originalName: string;
  contentType: string;
  fileSize: number;
  status: string;
};

export type AuthPayload = {
  email: string;
  password: string;
  nickname?: string;
};

export async function getStoredTokens(): Promise<TokenResponse | null> {
  const [accessToken, refreshToken] = await Promise.all([
    AsyncStorage.getItem(ACCESS_TOKEN_KEY),
    AsyncStorage.getItem(REFRESH_TOKEN_KEY),
  ]);
  return accessToken && refreshToken ? { accessToken, refreshToken } : null;
}

export async function storeTokens(tokens: TokenResponse): Promise<void> {
  await AsyncStorage.multiSet([
    [ACCESS_TOKEN_KEY, tokens.accessToken],
    [REFRESH_TOKEN_KEY, tokens.refreshToken],
  ]);
}

export async function clearTokens(): Promise<void> {
  await AsyncStorage.multiRemove([ACCESS_TOKEN_KEY, REFRESH_TOKEN_KEY]);
}

async function request<T>(path: string, init: RequestInit = {}, retry = true): Promise<T> {
  const tokens = await getStoredTokens();
  const headers = new Headers(init.headers);
  headers.set('Accept', 'application/json');
  if (!(init.body instanceof FormData)) headers.set('Content-Type', 'application/json');
  if (tokens?.accessToken) headers.set('Authorization', `Bearer ${tokens.accessToken}`);

  const response = await fetch(`${API_BASE_URL}${path}`, { ...init, headers });

  if (response.status === 401 && retry && tokens?.refreshToken) {
    const refreshed = await refresh(tokens.refreshToken);
    if (refreshed) return request<T>(path, init, false);
  }

  if (!response.ok) {
    const body = await readError(response);
    throw new Error(body || `Request failed with status ${response.status}`);
  }

  if (response.status === 204) return undefined as T;

  const body = await response.json();
  return (body.data ?? body) as T;
}

async function readError(response: Response): Promise<string> {
  try {
    const body = await response.json();
    return body.detail ?? body.title ?? body.message ?? '';
  } catch {
    return '';
  }
}

async function refresh(refreshToken: string): Promise<TokenResponse | null> {
  const response = await fetch(`${API_BASE_URL}/api/v1/auth/refresh`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
    body: JSON.stringify({ refreshToken }),
  });
  if (!response.ok) {
    await clearTokens();
    return null;
  }
  const body = (await response.json()) as ApiResponse<TokenResponse>;
  await storeTokens(body.data);
  return body.data;
}

function mapPet(pet: BackendPet): Pet {
  return { ...pet, id: String(pet.id) };
}

function mapRecord(record: BackendRecord): ActivityRecord {
  return {
    ...(record.detail ?? {}),
    id: String(record.id),
    petId: String(record.petId),
    typeId: record.typeId,
    date: record.date,
    ...(record.time ? { time: record.time.slice(0, 5) } : {}),
    ...(record.routineId ? { routineId: String(record.routineId) } : {}),
    ...(record.note ? { note: record.note } : {}),
    ...(record.mediaUrls && record.mediaUrls.length > 0 ? { poopPhotos: record.mediaUrls.map(mediaUrl) } : {}),
  } as ActivityRecord;
}

function recordPayload(record: Partial<ActivityRecord>) {
  const { id, petId, typeId, date, time, routineId, note, poopPhotos, ...detail } = record;
  return {
    ...(typeId ? { typeId } : {}),
    ...(date ? { date } : {}),
    ...(time ? { time } : {}),
    ...(routineId ? { routineId } : {}),
    ...(note ? { note } : {}),
    detail,
  };
}

function mediaUrl(url: string): string {
  return url.startsWith('http') ? url : `${API_BASE_URL}${url}`;
}

function filePart(asset: string | UploadAsset) {
  return createUploadFilePart(asset) as unknown as Blob;
}

function mapRoutine(routine: BackendRoutine): Routine {
  return {
    id: String(routine.id),
    petId: String(routine.petId),
    label: routine.label,
    typeId: routine.typeId,
    repeatType: routine.repeatType,
    days: routine.days ?? [],
    monthlyInterval: routine.monthlyInterval ?? undefined,
    startDate: routine.startDate,
    times: routine.times ?? [],
    ...(routine.note ? { note: routine.note } : {}),
    ...(routine.detail ? { detail: routine.detail as Partial<ActivityRecord> } : {}),
    notificationEnabled: false,
    notificationIds: [],
  };
}

function routinePayload(routine: Partial<Routine>) {
  const { id, petId, notificationIds, ...payload } = routine;
  return payload;
}

function mapPost(post: BackendPost): Post {
  return {
    id: String(post.id),
    author: post.authorNickname,
    title: post.title,
    category: post.category,
    petSpecies: post.petSpecies ?? 'dog',
    content: post.content,
    likes: post.likesCount,
    commentsCount: post.commentsCount,
    likedByMe: post.liked,
    createdAt: post.createdAt,
    mediaUrls: (post.mediaUrls ?? []).map(mediaUrl),
    poll: post.poll ? {
      id: String(post.poll.id),
      question: post.poll.question,
      options: post.poll.options.map((option) => ({
        id: String(option.id),
        label: option.label,
        votesCount: option.votesCount,
        votedByMe: option.votedByMe,
      })),
    } : null,
  };
}

function mapProfile(profile: UserProfile): UserProfile {
  return {
    ...profile,
    profileImageUrl: profile.profileImageUrl ? mediaUrl(profile.profileImageUrl) : null,
  };
}

export const authApi = {
  async register(payload: Required<AuthPayload>) {
    const tokens = await request<TokenResponse>('/api/v1/auth/register', {
      method: 'POST',
      body: JSON.stringify(payload),
    });
    await storeTokens(tokens);
    return tokens;
  },
  async login(payload: Omit<AuthPayload, 'nickname'>) {
    const tokens = await request<TokenResponse>('/api/v1/auth/login', {
      method: 'POST',
      body: JSON.stringify(payload),
    });
    await storeTokens(tokens);
    return tokens;
  },
  async logout() {
    const tokens = await getStoredTokens();
    if (tokens?.refreshToken) {
      await request<void>('/api/v1/auth/logout', {
        method: 'POST',
        body: JSON.stringify({ refreshToken: tokens.refreshToken }),
      }).catch(() => undefined);
    }
    await clearTokens();
  },
};

export const userApi = {
  async getMe() {
    return mapProfile(await request<UserProfile>('/api/v1/users/me'));
  },
  async updateMe(nickname: string) {
    return mapProfile(await request<UserProfile>('/api/v1/users/me', {
      method: 'PATCH',
      body: JSON.stringify({ nickname }),
    }));
  },
  async uploadProfileImage(uri: string) {
    const form = new FormData();
    form.append('file', filePart(uri));
    return mapProfile(await request<UserProfile>('/api/v1/users/me/profile-image', {
      method: 'POST',
      body: form,
    }));
  },
};

export const petApi = {
  list: async () => (await request<BackendPet[]>('/api/v1/pets')).map(mapPet),
  create: async (pet: Omit<Pet, 'id' | 'accentColor' | 'bgLight'>) =>
    mapPet(await request<BackendPet>('/api/v1/pets', { method: 'POST', body: JSON.stringify(pet) })),
  update: async (id: string, updates: Partial<Omit<Pet, 'id' | 'accentColor' | 'bgLight'>>) =>
    mapPet(await request<BackendPet>(`/api/v1/pets/${id}`, { method: 'PUT', body: JSON.stringify(updates) })),
  remove: async (id: string) => request<void>(`/api/v1/pets/${id}`, { method: 'DELETE' }),
};

export const recordApi = {
  list: async (petId: string) => (await request<BackendRecord[]>(`/api/v1/pets/${petId}/records`)).map(mapRecord),
  create: async (petId: string, record: Omit<ActivityRecord, 'id'>) =>
    mapRecord(await request<BackendRecord>(`/api/v1/pets/${petId}/records`, {
      method: 'POST',
      body: JSON.stringify(recordPayload(record)),
    })),
  update: async (petId: string, recordId: string, updates: Partial<Omit<ActivityRecord, 'id'>>) =>
    mapRecord(await request<BackendRecord>(`/api/v1/pets/${petId}/records/${recordId}`, {
      method: 'PUT',
      body: JSON.stringify(recordPayload(updates)),
    })),
  remove: async (petId: string, recordId: string) =>
    request<void>(`/api/v1/pets/${petId}/records/${recordId}`, { method: 'DELETE' }),
};

export const mediaApi = {
  async uploadRecord(petId: string, recordId: string, uri: string) {
    const form = new FormData();
    form.append('file', filePart(uri));
    const media = await request<MediaResponse>(`/api/v1/pets/${petId}/records/${recordId}/media`, {
      method: 'POST',
      body: form,
    });
    return { ...media, url: mediaUrl(media.url) };
  },
  async uploadPet(petId: string, uri: string) {
    const form = new FormData();
    form.append('file', filePart(uri));
    const media = await request<MediaResponse>(`/api/v1/pets/${petId}/media`, {
      method: 'POST',
      body: form,
    });
    return { ...media, url: mediaUrl(media.url) };
  },
};

export const routineApi = {
  list: async (petId: string) => (await request<BackendRoutine[]>(`/api/v1/pets/${petId}/routines`)).map(mapRoutine),
  today: async (petId: string, date: string) =>
    (await request<BackendTodayRoutineResponse>(`/api/v1/pets/${petId}/routines/today?date=${date}`)).routines.map((item) => ({
      routine: mapRoutine(item.routine),
      completion: {
        routineId: String(item.completion.routineId),
        scheduledDate: item.completion.scheduledDate,
        status: item.completion.status,
      },
    })),
  create: async (petId: string, routine: Omit<Routine, 'id' | 'notificationIds'>) =>
    mapRoutine(await request<BackendRoutine>(`/api/v1/pets/${petId}/routines`, {
      method: 'POST',
      body: JSON.stringify({ ...routinePayload(routine), notificationEnabled: false }),
    })),
  update: async (petId: string, routineId: string, updates: Partial<Routine>) =>
    mapRoutine(await request<BackendRoutine>(`/api/v1/pets/${petId}/routines/${routineId}`, {
      method: 'PUT',
      body: JSON.stringify({ ...routinePayload(updates), notificationEnabled: false }),
    })),
  complete: async (petId: string, routineId: string, date: string, status: RoutineCompletionStatus) =>
    request<BackendRoutineCompletion>(`/api/v1/pets/${petId}/routines/${routineId}/completions/${date}`, {
      method: 'PATCH',
      body: JSON.stringify({ status }),
    }),
  remove: async (petId: string, routineId: string) =>
    request<void>(`/api/v1/pets/${petId}/routines/${routineId}`, { method: 'DELETE' }),
};

export const communityApi = {
  async feed(options: { category?: string; sort?: 'latest' | 'popular'; cursor?: string; limit?: number } = {}) {
    const params = new URLSearchParams({ limit: String(options.limit ?? 10), sort: options.sort ?? 'latest' });
    if (options.category) params.set('category', options.category);
    if (options.cursor) params.set('cursor', options.cursor);
    const feed = await request<FeedResponse>(`/api/v1/posts?${params.toString()}`);
    return { items: feed.items.map(mapPost), nextCursor: feed.nextCursor };
  },
  create: async (
    payload: { title: string; category: string; content: string; poll?: { question: string; options: string[] } | null },
    files: UploadAsset[] = [],
  ) => {
    const form = new FormData();
    form.append('payload', JSON.stringify(payload));
    files.forEach((file) => form.append('files', filePart(file)));
    return mapPost(await request<BackendPost>('/api/v1/posts', { method: 'POST', body: form }));
  },
  like: async (postId: string) => {
    const like = await request<BackendPostLike>(`/api/v1/posts/${postId}/like`, { method: 'POST' });
    return { postId: String(like.postId), likedByMe: like.liked, likes: like.likesCount };
  },
  vote: async (postId: string, optionId: string) =>
    mapPost(await request<BackendPost>(`/api/v1/posts/${postId}/poll/options/${optionId}/vote`, { method: 'POST' })),
};
