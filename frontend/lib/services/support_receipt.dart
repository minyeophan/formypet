DateTime? parseSupportReceiptTime(Object? value) {
  if (value is! String) return null;
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d+)?(?:Z|[+-](\d{2}):(\d{2}))$',
  ).firstMatch(value);
  if (match == null) return null;
  final parts = [for (var i = 1; i <= 6; i++) int.parse(match.group(i)!)];
  final local = DateTime.utc(
    parts[0],
    parts[1],
    parts[2],
    parts[3],
    parts[4],
    parts[5],
  );
  // DateTime.parse normalizes impossible dates rather than rejecting them.
  final actual = [
    local.year,
    local.month,
    local.day,
    local.hour,
    local.minute,
    local.second,
  ];
  for (var i = 0; i < parts.length; i++) {
    if (parts[i] != actual[i]) return null;
  }
  if (match.group(7) != null &&
      (int.parse(match.group(7)!) > 23 || int.parse(match.group(8)!) > 59)) {
    return null;
  }
  return DateTime.tryParse(value);
}
