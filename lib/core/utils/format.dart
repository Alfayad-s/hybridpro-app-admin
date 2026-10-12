import 'package:intl/intl.dart';

final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _date = DateFormat('dd MMM yyyy');
final _dateTime = DateFormat('dd MMM yyyy, HH:mm');

String formatPaise(int paise) => _inr.format(paise / 100);

String formatDate(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return _date.format(d.toLocal());
}

String formatDateTime(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return _dateTime.format(d.toLocal());
}

String planLabel(String planId) {
  switch (planId) {
    case 'foundation':
      return 'Foundation';
    case 'performance':
      return 'Performance';
    case 'elite':
      return 'Elite';
    default:
      return planId;
  }
}
