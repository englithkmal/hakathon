import 'package:intl/intl.dart' hide TextDirection;

final NumberFormat kHomeMoneyFormat = NumberFormat('#,##0.00', 'en_US');

String formatHomeMoney(double amount, String currency) =>
    '${kHomeMoneyFormat.format(amount)} $currency';
