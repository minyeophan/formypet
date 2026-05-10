import { Alert } from 'react-native';
import { Routine } from '../types';

type NotificationsModule = {
  getPermissionsAsync: () => Promise<{ status: string }>;
  requestPermissionsAsync: () => Promise<{ status: string }>;
  scheduleNotificationAsync: (request: {
    content: { title: string; body: string };
    trigger: any;
  }) => Promise<string>;
  cancelScheduledNotificationAsync: (identifier: string) => Promise<void>;
};

// Graceful degradation — expo-notifications may not be installed
let Notifications: NotificationsModule | null = null;
try {
  Notifications = require('expo-notifications');
} catch {
  Notifications = null;
}

export async function requestPermission(): Promise<boolean> {
  if (!Notifications) return false;
  const { status: existing } = await Notifications.getPermissionsAsync();
  if (existing === 'granted') return true;
  const { status } = await Notifications.requestPermissionsAsync();
  if (status !== 'granted') {
    Alert.alert(
      '알림 권한 필요',
      '루틴 알림을 받으려면 설정에서 알림 권한을 허용해 주세요.',
      [{ text: '확인' }],
    );
    return false;
  }
  return true;
}

export async function scheduleRoutineNotifications(
  routine: Routine,
  petName: string,
): Promise<string[]> {
  if (!Notifications || routine.times.length === 0) return [];

  const ids: string[] = [];
  for (const time of routine.times) {
    const [hourStr, minuteStr] = time.split(':');
    const hour = parseInt(hourStr, 10);
    const minute = parseInt(minuteStr, 10);
    if (isNaN(hour) || isNaN(minute)) continue;

    if (routine.repeatType === 'daily') {
      const id = await Notifications.scheduleNotificationAsync({
        content: {
          title: `${petName}의 ${routine.label}`,
          body: `${time} 루틴 시간이에요 ✅`,
        },
        trigger: { type: 'daily', hour, minute, repeats: true } as any,
      });
      ids.push(id);
    } else {
      for (const day of routine.days) {
        const id = await Notifications.scheduleNotificationAsync({
          content: {
            title: `${petName}의 ${routine.label}`,
            body: `${time} 루틴 시간이에요 ✅`,
          },
          trigger: { type: 'weekly', weekday: day + 1, hour, minute, repeats: true } as any,
        });
        ids.push(id);
      }
    }
  }
  return ids;
}

export async function cancelRoutineNotifications(routine: Routine): Promise<void> {
  if (!Notifications || routine.notificationIds.length === 0) return;
  for (const id of routine.notificationIds) {
    await Notifications.cancelScheduledNotificationAsync(id);
  }
}
