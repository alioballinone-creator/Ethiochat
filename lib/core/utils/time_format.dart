import 'package:intl/intl.dart';

/// Compact timestamp used in the chat list: time today, "Yesterday", weekday
/// within the last week, then a short date.
String chatListTime(DateTime? time) {
  if (time == null) return '';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(time.year, time.month, time.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return DateFormat.Hm().format(time);
  if (diff == 1) return 'Yesterday';
  if (diff < 7) return DateFormat.E().format(time);
  if (time.year == now.year) return DateFormat.MMMd().format(time);
  return DateFormat.yMd().format(time);
}

String bubbleTime(DateTime time) => DateFormat.Hm().format(time);

String dayLabel(DateTime time) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(time.year, time.month, time.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return DateFormat.yMMMd().format(time);
}
