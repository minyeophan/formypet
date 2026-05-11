import AsyncStorage from '@react-native-async-storage/async-storage';
import React, { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { Pet, ActivityRecord, Routine } from '../types';
import { DEFAULT_QUICK_IDS, SUPPORTED_RECORD_TYPE_IDS } from './record-types';
import { todayString } from './utils';
import { useAuth } from './auth-context';
import { mediaApi, petApi, recordApi, routineApi } from '../services/api';
import { saveRecordWithMedia } from './record-save';

type RoutineCompletionStatus = 'PENDING' | 'COMPLETED';

interface PetContextValue {
  isLoading: boolean;
  hasOnboarded: boolean;
  setHasOnboarded: (v: boolean) => void;

  pets: Pet[];
  activePetId: string;
  setActivePetId: (id: string) => void;
  addPet: (pet: Omit<Pet, 'id' | 'accentColor' | 'bgLight'>) => Promise<void>;
  updatePet: (petId: string, updates: Partial<Omit<Pet, 'id' | 'accentColor' | 'bgLight'>>) => Promise<void>;
  deletePet: (petId: string) => Promise<void>;

  records: ActivityRecord[];
  addRecord: (record: Omit<ActivityRecord, 'id'>) => Promise<void>;
  updateRecord: (recordId: string, updates: Partial<Omit<ActivityRecord, 'id'>>) => Promise<void>;
  deleteRecord: (recordId: string) => Promise<void>;

  openModal: (typeId: string | null, date?: string, routineId?: string, initialDraft?: Partial<ActivityRecord>) => void;
  closeModal: () => void;
  modalOpen: boolean;
  selectedType: string | null;
  modalDate: string;
  modalRoutineId: string | undefined;
  modalInitialDraft: Partial<ActivityRecord> | undefined;

  quickTypeIds: string[];
  setQuickTypeIds: (ids: string[]) => void;

  routines: Routine[];
  addRoutine: (r: Omit<Routine, 'id' | 'notificationIds'>) => Promise<Routine>;
  updateRoutine: (id: string, updates: Partial<Routine>) => Promise<void>;
  deleteRoutine: (id: string) => Promise<void>;
  getRoutineCompletionStatus: (routineId: string, date: string) => RoutineCompletionStatus;
  markRoutineCompletion: (routineId: string, date: string, status: RoutineCompletionStatus) => Promise<void>;
}

const PetContext = createContext<PetContextValue | null>(null);

export function PetProvider({ children }: { children: React.ReactNode }) {
  const { isAuthenticated } = useAuth();
  const [isLoading, setIsLoading] = useState(true);
  const [hasOnboarded, setHasOnboardedState] = useState(false);
  const [pets, setPets] = useState<Pet[]>([]);
  const [activePetId, setActivePetId] = useState('');
  const [records, setRecords] = useState<ActivityRecord[]>([]);
  const [modalOpen, setModalOpen] = useState(false);
  const [selectedType, setSelectedType] = useState<string | null>(null);
  const [modalDate, setModalDate] = useState(todayString());
  const [modalRoutineId, setModalRoutineId] = useState<string | undefined>(undefined);
  const [modalInitialDraft, setModalInitialDraft] = useState<Partial<ActivityRecord> | undefined>(undefined);
  const [quickTypeIds, setQuickTypeIdsState] = useState<string[]>(DEFAULT_QUICK_IDS);
  const [routines, setRoutines] = useState<Routine[]>([]);
  const [routineCompletions, setRoutineCompletions] = useState<Record<string, RoutineCompletionStatus>>({});

  useEffect(() => {
    let cancelled = false;

    async function load() {
      setIsLoading(true);
      try {
        const quickIdsRaw = await AsyncStorage.getItem('quickTypeIds');
        if (quickIdsRaw) {
          const parsed = JSON.parse(quickIdsRaw);
          if (Array.isArray(parsed)) {
            setQuickTypeIdsState(parsed.filter((id) => SUPPORTED_RECORD_TYPE_IDS.includes(id)));
          }
        }

        if (!isAuthenticated) {
          setPets([]);
          setRecords([]);
          setRoutines([]);
          setRoutineCompletions({});
          setActivePetId('');
          setHasOnboardedState(false);
          return;
        }

        const loadedPets = await petApi.list();
        if (cancelled) return;
        setPets(loadedPets);
        setActivePetId((current) => current || loadedPets[0]?.id || '');
        setHasOnboardedState(loadedPets.length > 0);

        const recordSets = await Promise.all(loadedPets.map((pet) => recordApi.list(pet.id)));
        const routineSets = await Promise.all(loadedPets.map((pet) => routineApi.list(pet.id)));
        const today = todayString();
        const todaySets = await Promise.all(loadedPets.map((pet) => routineApi.today(pet.id, today)));
        if (cancelled) return;
        setRecords(recordSets.flat());
        setRoutines(routineSets.flat());
        setRoutineCompletions(() => {
          const next: Record<string, RoutineCompletionStatus> = {};
          for (const item of todaySets.flat()) {
            next[completionKey(item.completion.routineId, item.completion.scheduledDate)] = item.completion.status;
          }
          return next;
        });
      } catch {
        if (!cancelled) {
          setPets([]);
          setRecords([]);
          setRoutines([]);
          setRoutineCompletions({});
          setActivePetId('');
          setHasOnboardedState(false);
        }
      } finally {
        if (!cancelled) setIsLoading(false);
      }
    }

    load();
    return () => {
      cancelled = true;
    };
  }, [isAuthenticated]);

  const setHasOnboarded = useCallback((v: boolean) => {
    setHasOnboardedState(v);
  }, []);

  const addPet = useCallback(async (pet: Omit<Pet, 'id' | 'accentColor' | 'bgLight'>) => {
    const newPet = await petApi.create(pet);
    setPets((prev) => [...prev, newPet]);
    if (!activePetId) setActivePetId(newPet.id);
  }, [activePetId]);

  const updatePet = useCallback(async (petId: string, updates: Partial<Omit<Pet, 'id' | 'accentColor' | 'bgLight'>>) => {
    const saved = await petApi.update(petId, updates);
    setPets((prev) => prev.map((p) => (p.id === petId ? saved : p)));
  }, []);

  const deletePet = useCallback(async (petId: string) => {
    await petApi.remove(petId);
    setPets((prev) => {
      const updatedPets = prev.filter((p) => p.id !== petId);
      if (activePetId === petId) setActivePetId(updatedPets[0]?.id ?? '');
      return updatedPets;
    });
    setRecords((prev) => prev.filter((r) => r.petId !== petId));
    setRoutines((prev) => prev.filter((r) => r.petId !== petId));
  }, [activePetId]);

  const addRecord = useCallback(async (record: Omit<ActivityRecord, 'id'>) => {
    const saved = await saveRecordWithMedia(record, {
      createRecord: (draft) => recordApi.create(draft.petId, draft),
      uploadRecord: mediaApi.uploadRecord,
      removeRecord: recordApi.remove,
    });
    setRecords((prev) => [...prev, saved]);
  }, []);

  const updateRecord = useCallback(async (recordId: string, updates: Partial<Omit<ActivityRecord, 'id'>>) => {
    const existing = records.find((r) => r.id === recordId);
    if (!existing) return;
    const saved = await recordApi.update(existing.petId, recordId, updates);
    const merged = {
      ...saved,
      poopPhotos: saved.poopPhotos ?? existing.poopPhotos,
    };
    setRecords((prev) => prev.map((r) => (r.id === recordId ? merged : r)));
  }, [records]);

  const deleteRecord = useCallback(async (recordId: string) => {
    const existing = records.find((r) => r.id === recordId);
    if (existing) await recordApi.remove(existing.petId, recordId);
    setRecords((prev) => prev.filter((r) => r.id !== recordId));
  }, [records]);

  const openModal = useCallback((typeId: string | null, date?: string, routineId?: string, initialDraft?: Partial<ActivityRecord>) => {
    setSelectedType(typeId);
    if (date !== undefined) setModalDate(date);
    setModalRoutineId(routineId);
    setModalInitialDraft(initialDraft);
    setModalOpen(true);
  }, []);

  const closeModal = useCallback(() => {
    setModalOpen(false);
    setSelectedType(null);
    setModalDate(todayString());
    setModalRoutineId(undefined);
    setModalInitialDraft(undefined);
  }, []);

  const addRoutine = useCallback(async (r: Omit<Routine, 'id' | 'notificationIds'>): Promise<Routine> => {
    const newRoutine = await routineApi.create(r.petId, r);
    setRoutines((prev) => [...prev, newRoutine]);
    return newRoutine;
  }, []);

  const updateRoutine = useCallback(async (id: string, updates: Partial<Routine>) => {
    const existing = routines.find((r) => r.id === id);
    if (!existing) return;
    const saved = await routineApi.update(existing.petId, id, updates);
    setRoutines((prev) => prev.map((r) => (r.id === id ? { ...r, ...saved, notificationIds: updates.notificationIds ?? r.notificationIds } : r)));
  }, [routines]);

  const deleteRoutine = useCallback(async (id: string) => {
    const existing = routines.find((r) => r.id === id);
    if (existing) await routineApi.remove(existing.petId, id);
    setRoutines((prev) => prev.filter((r) => r.id !== id));
    setRoutineCompletions((prev) => {
      const next = { ...prev };
      for (const key of Object.keys(next)) {
        if (key.startsWith(`${id}:`)) delete next[key];
      }
      return next;
    });
  }, [routines]);

  const getRoutineCompletionStatus = useCallback((routineId: string, date: string): RoutineCompletionStatus => {
    return routineCompletions[completionKey(routineId, date)] ?? 'PENDING';
  }, [routineCompletions]);

  const markRoutineCompletion = useCallback(async (routineId: string, date: string, status: RoutineCompletionStatus) => {
    const existing = routines.find((r) => r.id === routineId);
    if (!existing) return;
    await routineApi.complete(existing.petId, routineId, date, status);
    setRoutineCompletions((prev) => ({ ...prev, [completionKey(routineId, date)]: status }));
  }, [routines]);

  const setQuickTypeIds = useCallback((ids: string[]) => {
    const supportedIds = ids.filter((id) => SUPPORTED_RECORD_TYPE_IDS.includes(id));
    setQuickTypeIdsState(supportedIds);
    AsyncStorage.setItem('quickTypeIds', JSON.stringify(supportedIds));
  }, []);

  const value = useMemo<PetContextValue>(() => ({
    isLoading,
    hasOnboarded,
    setHasOnboarded,
    pets,
    activePetId,
    setActivePetId,
    addPet,
    updatePet,
    deletePet,
    records,
    addRecord,
    updateRecord,
    deleteRecord,
    openModal,
    closeModal,
    modalOpen,
    selectedType,
    modalDate,
    modalRoutineId,
    modalInitialDraft,
    quickTypeIds,
    setQuickTypeIds,
    routines,
    addRoutine,
    updateRoutine,
    deleteRoutine,
    getRoutineCompletionStatus,
    markRoutineCompletion,
  }), [
    isLoading,
    hasOnboarded,
    pets,
    activePetId,
    addPet,
    updatePet,
    deletePet,
    records,
    addRecord,
    updateRecord,
    deleteRecord,
    openModal,
    closeModal,
    modalOpen,
    selectedType,
    modalDate,
    modalRoutineId,
    modalInitialDraft,
    quickTypeIds,
    setQuickTypeIds,
    routines,
    addRoutine,
    updateRoutine,
    deleteRoutine,
    getRoutineCompletionStatus,
    markRoutineCompletion,
  ]);

  return (
    <PetContext.Provider value={value}>
      {children}
    </PetContext.Provider>
  );
}

function completionKey(routineId: string, date: string): string {
  return `${routineId}:${date}`;
}

export function usePets(): PetContextValue {
  const ctx = useContext(PetContext);
  if (!ctx) throw new Error('usePets must be used within PetProvider');
  return ctx;
}
