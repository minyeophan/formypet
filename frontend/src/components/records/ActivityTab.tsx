import { usePets } from '@/src/lib/pet-context';
import { getRecordsByPet, groupRecordsByDate } from '@/src/services/records';
import RecordList from './RecordList';

export default function ActivityTab() {
  const { pets, activePetId, records } = usePets();
  const pet = pets.find((p) => p.id === activePetId);
  if (!pet) return null;

  const filtered = getRecordsByPet(records, pet.id).filter((r) =>
    ['meal', 'walk', 'play', 'sleep'].includes(r.typeId)
  );
  const sections = groupRecordsByDate(filtered);

  return <RecordList sections={sections} />;
}
