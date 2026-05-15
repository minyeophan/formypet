import 'package:intl/intl.dart';

String todayString() => DateFormat('yyyy-MM-dd').format(DateTime.now());

String formatDate(DateTime date) => DateFormat('yyyy년 M월 d일').format(date);

String formatDateShort(String isoDate) {
  final d = DateTime.parse(isoDate);
  return DateFormat('M월 d일').format(d);
}

String formatDateSection(String isoDate) {
  final d = DateTime.parse(isoDate);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(d.year, d.month, d.day);
  final diff = today.difference(target).inDays;
  if (diff == 0) return '오늘';
  if (diff == 1) return '어제';
  return DateFormat('M월 d일').format(d);
}

String getDDay(String birthDateIso) {
  final birth = DateTime.parse(birthDateIso);
  final now = DateTime.now();
  final diff = now.difference(birth).inDays;
  return 'D+$diff';
}

String formatTime12h(String? timeHHMM) {
  if (timeHHMM == null) return '';
  final parts = timeHHMM.split(':');
  if (parts.length < 2) return timeHHMM;
  final h = int.tryParse(parts[0]) ?? 0;
  final m = int.tryParse(parts[1]) ?? 0;
  final period = h < 12 ? '오전' : '오후';
  final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  return '$period $hour12:${m.toString().padLeft(2, '0')}';
}

List<DateTime> getCalendarDays(int year, int month) {
  final first = DateTime(year, month, 1);
  final last = DateTime(year, month + 1, 0);
  final startOffset = first.weekday % 7; // Sunday=0
  final days = <DateTime>[];
  for (int i = 0; i < startOffset; i++) {
    days.add(first.subtract(Duration(days: startOffset - i)));
  }
  for (int d = 1; d <= last.day; d++) {
    days.add(DateTime(year, month, d));
  }
  return days;
}
