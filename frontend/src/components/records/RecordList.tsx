import { SectionList, View } from 'react-native';
import { ActivityRecord } from '@/src/types';
import { QUICK_TYPES } from '@/src/lib/record-types';
import { formatDateSection, formatDateShort } from '@/src/lib/utils';
import { RecordSection } from '@/src/services/records';
import { colors } from '@/src/lib/colors';
import AppText from '../shared/AppText';

interface Props {
  sections: RecordSection[];
}

export default function RecordList({ sections }: Props) {
  if (sections.length === 0) {
    return (
      <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', paddingVertical: 60 }}>
        <View style={{ backgroundColor: colors.surfaceSoft, borderRadius: 18, borderWidth: 1, borderColor: colors.border, paddingHorizontal: 28, paddingVertical: 24, alignItems: 'center' }}>
          <AppText style={{ fontSize: 36, marginBottom: 12 }}>🐾</AppText>
          <AppText style={{ fontSize: 15, color: colors.muted }}>기록이 없어요</AppText>
        </View>
      </View>
    );
  }

  return (
    <SectionList
      sections={sections}
      keyExtractor={(item) => item.id}
      contentContainerStyle={{ paddingHorizontal: 20, paddingBottom: 24 }}
      stickySectionHeadersEnabled={false}
      renderSectionHeader={({ section }) => (
        <AppText
          bold
          style={{ fontSize: 13, color: '#6B6B6B', marginTop: 20, marginBottom: 8 }}
        >
          {formatDateSection(section.title)}
        </AppText>
      )}
      ItemSeparatorComponent={() => <View style={{ height: 8 }} />}
      renderItem={({ item }: { item: ActivityRecord }) => {
        const typeInfo = QUICK_TYPES.find((t) => t.id === item.typeId);
        return (
          <View
            style={{
              backgroundColor: colors.surface,
              borderRadius: 16,
              borderWidth: 1,
              borderColor: colors.border,
              padding: 14,
              flexDirection: 'row',
              alignItems: 'center',
              gap: 12,
            }}
          >
            <View
              style={{
                width: 44,
                height: 44,
                borderRadius: 13,
                backgroundColor: typeInfo?.bg ?? colors.surfaceSoft,
                borderWidth: 1,
                borderColor: colors.border,
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              <AppText style={{ fontSize: 22 }}>{typeInfo?.emoji ?? '📝'}</AppText>
            </View>
            <View style={{ flex: 1 }}>
              <AppText bold style={{ fontSize: 14, color: colors.text }}>
                {typeInfo?.label ?? item.typeId}
                {item.weight ? ` · ${item.weight}kg` : ''}
              </AppText>
              {item.note ? (
                <AppText style={{ fontSize: 12, color: colors.textSecondary, marginTop: 2 }} numberOfLines={2}>
                  {item.note}
                </AppText>
              ) : null}
            </View>
          </View>
        );
      }}
    />
  );
}
