import 'package:intl/intl.dart';

final NumberFormat _currencyFormat =
    NumberFormat.currency(locale: 'sw_TZ', symbol: 'TZS ');

String formatCurrency(num value) {
  return _currencyFormat.format(value);
}

String formatCompact(num value) {
  return NumberFormat.compact(locale: 'en').format(value);
}

String formatDateTime(DateTime dateTime) {
  return DateFormat('dd MMM, hh:mm a').format(dateTime);
}
