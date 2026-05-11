import { useState } from 'react';
import { Pressable, ScrollView, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { usePets } from '@/src/lib/pet-context';
import { SUPPORTED_QUICK_TYPES } from '@/src/lib/record-types';
import { todayString } from '@/src/lib/utils';
import { colors } from '@/src/lib/colors';
import AppText from '../shared/AppText';
import QuickRecordIcon from '../shared/QuickRecordIcon';

export default function QuickRecord() {
  const { openModal, quickTypeIds, setQuickTypeIds, records, activePetId } = usePets();
  const [isEditing, setIsEditing] = useState(false);

  const selectedTypes = SUPPORTED_QUICK_TYPES.filter((t) => quickTypeIds.includes(t.id));
  const todayCount = records.filter((r) => r.petId === activePetId && r.date === todayString()).length;

  function toggleType(typeId: string) {
    const next = quickTypeIds.includes(typeId)
      ? quickTypeIds.filter((id) => id !== typeId)
      : [...quickTypeIds, typeId];
    setQuickTypeIds(next);
  }

  return (
    <View style={{ padding: 16 }}>
      {/* 헤더 */}
      <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 14 }}>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
          <AppText bold style={{ fontSize: 15, color: '#1A1A1A' }}>오늘의 기록</AppText>
          {todayCount > 0 && (
            <View style={{
              backgroundColor: colors.primary, borderRadius: 10,
              paddingHorizontal: 7, paddingVertical: 2,
            }}>
              <AppText bold style={{ fontSize: 11, color: '#FFFFFF' }}>{todayCount}</AppText>
            </View>
          )}
        </View>
        <Pressable onPress={() => setIsEditing(!isEditing)} hitSlop={8} style={{ padding: 4 }}>
          <Ionicons name={isEditing ? 'checkmark' : 'create-outline'} size={20} color={colors.primary} />
        </Pressable>
      </View>

      {isEditing ? (
        /* 편집 모드: 전체 항목 선택 */
        <>
          <AppText style={{ fontSize: 12, color: colors.muted, marginBottom: 12 }}>
            항목을 눌러 빠른 기록에 추가하거나 제거하세요
          </AppText>
          <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 10 }}>
            {SUPPORTED_QUICK_TYPES.map((item) => {
              const selected = quickTypeIds.includes(item.id);
              return (
                <Pressable
                  key={item.id}
                  onPress={() => toggleType(item.id)}
                  style={{
                    width: 72,
                    aspectRatio: 1,
                    borderRadius: 16,
                    backgroundColor: selected ? item.bg : colors.surfaceSoft,
                    alignItems: 'center',
                    justifyContent: 'center',
                    gap: 4,
                    borderWidth: 1.5,
                    borderColor: selected ? colors.primary : colors.border,
                  }}
                >
                  <QuickRecordIcon typeId={item.id} fallback={item.emoji} size={30} muted={!selected} />
                  <AppText style={{ fontSize: 10, color: selected ? colors.text : colors.muted }}>
                    {item.label}
                  </AppText>
                  {selected && (
                    <View style={{
                      position: 'absolute', top: 4, right: 4,
                      width: 16, height: 16, borderRadius: 8,
                      backgroundColor: colors.primary,
                      alignItems: 'center', justifyContent: 'center',
                    }}>
                      <AppText style={{ fontSize: 9, color: '#FFFFFF' }}>✓</AppText>
                    </View>
                  )}
                </Pressable>
              );
            })}
          </View>
        </>
      ) : (
        /* 일반 모드: 선택된 항목 가로 스크롤 */
        selectedTypes.length === 0 ? (
          <View style={{ paddingVertical: 16, alignItems: 'center' }}>
            <AppText style={{ fontSize: 26, marginBottom: 6 }}>🐾</AppText>
            <AppText style={{ fontSize: 13, color: colors.muted }}>수정을 눌러 항목을 추가해보세요</AppText>
          </View>
        ) : (
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 10 }}>
            {selectedTypes.map((item) => (
              <Pressable
                key={item.id}
                onPress={() => openModal(item.id)}
                style={{
                  width: 72,
                  aspectRatio: 1,
                  borderRadius: 16,
                  backgroundColor: item.bg,
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: 4,
                  borderWidth: 1,
                  borderColor: colors.border,
                }}
              >
                <QuickRecordIcon typeId={item.id} fallback={item.emoji} size={32} />
                <AppText style={{ fontSize: 11, color: colors.textSecondary }}>{item.label}</AppText>
              </Pressable>
            ))}
          </ScrollView>
        )
      )}
    </View>
  );
}
