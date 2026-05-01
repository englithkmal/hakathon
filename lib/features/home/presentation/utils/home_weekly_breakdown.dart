import '../../data/models/dashboard_model.dart';

/// Aggregated expenses for one ISO-week of the current calendar month.
class HomeWeeklyBucket {
  const HomeWeeklyBucket({required this.weekIndex, required this.amount});

  /// 1-based week index inside the month (1..5).
  final int weekIndex;
  final double amount;
}

/// Splits the dashboard's `recent_transactions` into 4 weekly buckets for
/// the current month so the home balance card can render the per-week
/// chips without an extra API round-trip.
///
/// Falls back to evenly distributing `summary.expenses` when there are no
/// recent transactions yet.
List<HomeWeeklyBucket> homeWeeklyBuckets(DashboardModel d) {
  final now = DateTime.now();
  final buckets = List<double>.filled(4, 0);

  for (final tx in d.recentTransactions) {
    if (tx.type != 'expense') continue;
    final when = DateTime.tryParse(tx.transactionDate)?.toLocal();
    if (when == null) continue;
    if (when.year != now.year || when.month != now.month) continue;
    final idx = _weekIndex(when.day);
    buckets[idx] += tx.amount.abs();
  }

  final hasData = buckets.any((v) => v > 0);
  if (!hasData) {
    final total = d.summary.expenses;
    if (total > 0) {
      final share = total / 4;
      return List.generate(
        4,
        (i) => HomeWeeklyBucket(weekIndex: i + 1, amount: share),
      );
    }
  }

  return List.generate(
    4,
    (i) => HomeWeeklyBucket(weekIndex: i + 1, amount: buckets[i]),
  );
}

/// Daily-grain points to feed into the line chart at the top of the
/// balance card. Returns `(dayOfMonth, cumulativeExpense)` pairs across
/// the current month so the curve can show a slope without depending on
/// a dedicated insights endpoint.
List<({int day, double value})> homeMonthSpendCurve(DashboardModel d) {
  final now = DateTime.now();
  final daysInMonth = DateUtils.lastDay(now);
  final daily = List<double>.filled(daysInMonth + 1, 0); // 1-based

  for (final tx in d.recentTransactions) {
    if (tx.type != 'expense') continue;
    final when = DateTime.tryParse(tx.transactionDate)?.toLocal();
    if (when == null) continue;
    if (when.year != now.year || when.month != now.month) continue;
    daily[when.day] += tx.amount.abs();
  }

  // Cumulative running total for a smoother, monotonic curve.
  double running = 0;
  final out = <({int day, double value})>[];
  for (var d = 1; d <= daysInMonth; d++) {
    running += daily[d];
    out.add((day: d, value: running));
  }
  return out;
}

int _weekIndex(int dayOfMonth) {
  if (dayOfMonth <= 7) return 0;
  if (dayOfMonth <= 14) return 1;
  if (dayOfMonth <= 21) return 2;
  return 3;
}

/// Tiny helper to avoid importing the full `intl` package for a number of
/// days in month.
class DateUtils {
  static int lastDay(DateTime m) {
    final firstNext = (m.month == 12)
        ? DateTime(m.year + 1, 1, 1)
        : DateTime(m.year, m.month + 1, 1);
    return firstNext.subtract(const Duration(days: 1)).day;
  }
}
