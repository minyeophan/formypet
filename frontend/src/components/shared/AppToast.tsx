import { Ionicons } from '@expo/vector-icons';
import { View } from 'react-native';
import Toast, { ToastConfig } from 'react-native-toast-message';
import { colors } from '@/src/lib/colors';
import AppText from './AppText';

type ToastKind = 'success' | 'error' | 'info';

const toastMeta: Record<ToastKind, { icon: keyof typeof Ionicons.glyphMap; color: string; bg: string }> = {
  success: { icon: 'checkmark-circle', color: colors.primary, bg: colors.primaryLight },
  error: { icon: 'alert-circle', color: '#EF4444', bg: '#FEF2F2' },
  info: { icon: 'information-circle', color: '#3B82F6', bg: '#EFF6FF' },
};

function AppToast({ kind, text1, text2 }: { kind: ToastKind; text1?: string; text2?: string }) {
  const meta = toastMeta[kind];

  return (
    <View
      style={{
        width: '90%',
        minHeight: 54,
        backgroundColor: colors.white,
        borderRadius: 16,
        paddingHorizontal: 14,
        paddingVertical: 12,
        flexDirection: 'row',
        alignItems: 'center',
        gap: 10,
        shadowColor: '#000000',
        shadowOffset: { width: 0, height: 4 },
        shadowOpacity: 0.12,
        shadowRadius: 12,
        elevation: 5,
      }}
    >
      <View
        style={{
          width: 28,
          height: 28,
          borderRadius: 14,
          backgroundColor: meta.bg,
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Ionicons name={meta.icon} size={17} color={meta.color} />
      </View>
      <View style={{ flex: 1 }}>
        <AppText bold style={{ fontSize: 14, color: colors.text }} numberOfLines={2}>
          {text1}
        </AppText>
        {text2 ? (
          <AppText style={{ fontSize: 12, color: colors.textSecondary, marginTop: 2 }} numberOfLines={2}>
            {text2}
          </AppText>
        ) : null}
      </View>
    </View>
  );
}

export const toastConfig: ToastConfig = {
  success: (params) => <AppToast kind="success" text1={params.text1} text2={params.text2} />,
  error: (params) => <AppToast kind="error" text1={params.text1} text2={params.text2} />,
  info: (params) => <AppToast kind="info" text1={params.text1} text2={params.text2} />,
};

export function showSuccessToast(message: string) {
  Toast.show({ type: 'success', text1: message, visibilityTime: 1800 });
}
