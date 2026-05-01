import '../../../../core/constants/app_constants.dart';

/// One row inside `GET /saving-goals/{id}/monthly-progress`.
///
/// Each row is a calendar month between the goal's `start_date` and
/// (today | deadline). `expected` is `monthly_target`, `deposited`
/// sums all `transaction(type=saving, saving_goal_id=...)` rows for
/// that month, and `delta = deposited - expected` (positive when
/// ahead, negative when behind).
class GoalMonthlyProgressItem {
  const GoalMonthlyProgressItem({
    required this.year,
    required this.month,
    required this.deposited,
    required this.transactionCount,
    required this.expected,
    required this.delta,
    required this.onTrack,
  });

  final int year;
  final int month;
  final double deposited;
  final int transactionCount;
  final double expected;
  final double delta;
  final bool onTrack;

  /// Convenience: actually-deposited / expected, clamped to [0, 1.5]
  /// so the UI can show "150% of target" without breaking the chart
  /// y-axis.
  double get coverage {
    if (expected <= 0) return deposited > 0 ? 1 : 0;
    return (deposited / expected).clamp(0.0, 1.5);
  }

  factory GoalMonthlyProgressItem.fromJson(Map<String, dynamic> json) {
    return GoalMonthlyProgressItem(
      year: _toInt(json['year']),
      month: _toInt(json['month']),
      deposited: _toDouble(json['deposited']),
      transactionCount: _toInt(json['transaction_count'] ?? json['count']),
      expected: _toDouble(json['expected']),
      delta: _toDouble(json['delta']),
      onTrack: json['on_track'] == true,
    );
  }
}

/// Full payload for `GET /saving-goals/{id}/monthly-progress`.
///
/// Wraps the per-month rows alongside the meta values the spec ships
/// (`monthly_target`, `goal_id`, `currency`) so the chart legend doesn't
/// have to dig back into [SavingGoalModel].
class GoalMonthlyProgress {
  const GoalMonthlyProgress({
    required this.items,
    required this.monthlyTarget,
    required this.goalId,
    required this.currency,
  });

  final List<GoalMonthlyProgressItem> items;
  final double monthlyTarget;
  final int goalId;
  final String currency;

  factory GoalMonthlyProgress.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final list = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((m) => GoalMonthlyProgressItem.fromJson(
                  m.cast<String, dynamic>(),
                ))
            .toList()
        : <GoalMonthlyProgressItem>[];
    final meta = json['meta'];
    if (meta is Map<String, dynamic>) {
      return GoalMonthlyProgress(
        items: list,
        monthlyTarget: _toDouble(
          meta['monthly_target'] ?? meta['monthlyTarget'],
        ),
        goalId: _toInt(meta['goal_id'] ?? meta['goalId']),
        currency:
            (meta['currency'] ?? AppConstants.defaultCurrency).toString(),
      );
    }
    return GoalMonthlyProgress(
      items: list,
      monthlyTarget: 0,
      goalId: 0,
      currency: AppConstants.defaultCurrency,
    );
  }
}

double _toDouble(Object? v) {
  if (v == null) return 0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

int _toInt(Object? v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}
