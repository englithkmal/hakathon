import 'package:flutter/foundation.dart';

/// How the backend (or client fallback) decided which month to show.
///
/// Mirrors the `source` field documented for `GET /period`. Keep the names
/// in sync with the strings the API returns; we tolerate unknown values
/// by mapping them to [PeriodSource.unknown] so a future server change
/// can never crash the app.
enum PeriodSource {
  /// Caller passed `?month=&year=` (or `?period_start=...`). The server
  /// honoured that exact period.
  explicit,

  /// Caller passed `?period_start=YYYY-MM-DD` and the server derived the
  /// month/year from it.
  periodStartParam,

  /// No query was sent and the server picked the user's most recent
  /// `active` budget month. The UI should surface a small banner
  /// explaining "showing month X because there is no budget for the
  /// current server month".
  latestBudget,

  /// No query, no recent budget — fell back to the server's current
  /// calendar month.
  serverNow,

  /// Used as a local fallback when the network is unreachable or when
  /// the server returns a value we don't recognise.
  unknown,
}

/// Active period the rest of the app should align to.
///
/// Constructed either from a real `GET /period` response or from a local
/// fallback (`SelectedPeriod.localFallback`) when the network call fails.
@immutable
class SelectedPeriod {
  const SelectedPeriod({
    required this.month,
    required this.year,
    required this.periodStart,
    required this.periodEnd,
    required this.source,
    this.budgetId,
  });

  final int month;
  final int year;

  /// `YYYY-MM-DD` strings — the server already computes them so the
  /// client doesn't have to reinvent calendar maths.
  final String periodStart;
  final String periodEnd;

  final PeriodSource source;

  /// `id` of the budget the period was anchored to. Populated when
  /// [source] is [PeriodSource.latestBudget] or when the requested
  /// month happens to have a matching budget. `null` otherwise.
  final int? budgetId;

  /// Quick check used by the UI to decide whether to render the
  /// "showing latest budget month" banner.
  bool get isFromLatestBudget => source == PeriodSource.latestBudget;

  /// Builds a [SelectedPeriod] from the server payload. Accepts the
  /// raw `period` map directly (unwrapped from either `data.period`
  /// or `meta.period`).
  factory SelectedPeriod.fromJson(Map<String, dynamic> json) {
    final m = _toInt(json['month']);
    final y = _toInt(json['year']);
    return SelectedPeriod(
      month: m == 0 ? DateTime.now().month : m,
      year: y == 0 ? DateTime.now().year : y,
      periodStart: (json['period_start'] ?? json['periodStart'] ?? '')
          .toString(),
      periodEnd: (json['period_end'] ?? json['periodEnd'] ?? '').toString(),
      source: _sourceFromString(
        (json['source'] ?? '').toString(),
      ),
      budgetId: json['budget_id'] is int
          ? json['budget_id'] as int
          : (json['budget_id'] is num
              ? (json['budget_id'] as num).toInt()
              : null),
    );
  }

  /// Computes a sensible default when we can't reach `GET /period` (e.g.
  /// offline cold-start). Uses the device clock and marks the source as
  /// [PeriodSource.unknown] so the UI can hide period-source affordances
  /// it would otherwise show.
  factory SelectedPeriod.localFallback() {
    final now = DateTime.now();
    final firstOfMonth = DateTime(now.year, now.month, 1);
    final lastOfMonth = DateTime(now.year, now.month + 1, 0);
    return SelectedPeriod(
      month: now.month,
      year: now.year,
      periodStart: _ymd(firstOfMonth),
      periodEnd: _ymd(lastOfMonth),
      source: PeriodSource.unknown,
    );
  }

  SelectedPeriod copyWith({
    int? month,
    int? year,
    String? periodStart,
    String? periodEnd,
    PeriodSource? source,
    int? budgetId,
  }) {
    return SelectedPeriod(
      month: month ?? this.month,
      year: year ?? this.year,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
      source: source ?? this.source,
      budgetId: budgetId ?? this.budgetId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SelectedPeriod &&
        other.month == month &&
        other.year == year &&
        other.periodStart == periodStart &&
        other.periodEnd == periodEnd &&
        other.source == source &&
        other.budgetId == budgetId;
  }

  @override
  int get hashCode =>
      Object.hash(month, year, periodStart, periodEnd, source, budgetId);

  @override
  String toString() =>
      'SelectedPeriod($year-$month, source=$source, budget=$budgetId)';
}

PeriodSource _sourceFromString(String raw) {
  switch (raw) {
    case 'explicit':
      return PeriodSource.explicit;
    case 'period_start':
    case 'period_start_param':
      return PeriodSource.periodStartParam;
    case 'latest_budget':
      return PeriodSource.latestBudget;
    case 'server_now':
      return PeriodSource.serverNow;
    default:
      return PeriodSource.unknown;
  }
}

int _toInt(Object? v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

String _ymd(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}
