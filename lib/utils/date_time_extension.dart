extension DateTimeExtension on DateTime {
  bool isSameDay(DateTime dateTime) {
    if (year == dateTime.year && month == dateTime.month && day == dateTime.day) {
      return true;
    }
    return false;
  }

  DateTime toSimpleDateTime() {
    return DateTime(year, month, day);
  }

  String toSimpleString() {
    return "$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}";
  }
}
