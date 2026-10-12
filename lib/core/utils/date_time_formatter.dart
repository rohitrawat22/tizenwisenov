import 'package:intl/intl.dart';

String formatDate(String isoDate) {
  final dateTime = DateTime.parse(isoDate);

  final day = dateTime.day.toString().padLeft(2, '0');
  final month = dateTime.month.toString().padLeft(2, '0');
  final year = dateTime.year;

  return "$day-$month-$year";
}

String formatTimeAMPM(String isoDate) {
  final dateTime = DateTime.parse(isoDate);
  return DateFormat('hh:mm a').format(dateTime);
}
