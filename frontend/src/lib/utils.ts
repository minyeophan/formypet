import { differenceInDays, format, parseISO, startOfMonth, endOfMonth, eachDayOfInterval } from 'date-fns';
import { ko } from 'date-fns/locale';

export function getDDay(birthDate: string): number {
  return differenceInDays(new Date(), parseISO(birthDate));
}

export function formatDate(dateStr: string): string {
  return format(parseISO(dateStr), 'yyyy.MM.dd', { locale: ko });
}

export function formatDateShort(dateStr: string): string {
  return format(parseISO(dateStr), 'M/d', { locale: ko });
}

export function formatDateSection(dateStr: string): string {
  return format(parseISO(dateStr), 'yyyy년 M월 d일 (E)', { locale: ko });
}

export function getCalendarDays(year: number, month: number): string[] {
  // month: 0-indexed (JavaScript standard)
  const start = startOfMonth(new Date(year, month));
  const end = endOfMonth(new Date(year, month));
  return eachDayOfInterval({ start, end }).map((d) => format(d, 'yyyy-MM-dd'));
}

export function todayString(): string {
  return format(new Date(), 'yyyy-MM-dd');
}
