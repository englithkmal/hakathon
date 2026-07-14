import '../../../../core/constants/app_constants.dart';

/// "Pace" rolling status the backend computes for each goal.
///
/// Mirrors the `pace.status` strings documented for `GET /saving-goals`,
/// `POST /saving-goals/{id}/deposit`, etc.
enum GoalPaceStatus {
  /// Saving faster than the schedule requires — `current_amount` is
  /// above `expected_at_today`.
  ahead,

  /// On schedule (within tolerance).
  onTrack,

  /// Behind schedule — `current_amount < expected_at_today`. The UI
  /// surfaces this as the warning state.
  offTrack,

  /// Goal is `paused`, `cancelled`, or already `achieved` — pace
  /// tracking doesn't apply.
  inactive,

  /// Goal lacks `start_date` / `deadline`, so the server can't compute
  /// pace at all.
  unscheduled,

  /// Forward-compat: any unknown future value lands here so UIs render
  /// a neutral state instead of crashing.
  unknown,
}

/// Pace summary for a single goal — when it's expected to reach its
/// monthly milestone and how far the user is ahead/behind.
class GoalPace {
  const GoalPace({
    required this.status,
    required this.monthlyTarget,
    required this.expectedAtToday,
    required this.delta,
  });

  final GoalPaceStatus status;

  /// `target_amount / months` — how much the user needs to save per
  /// month to hit the deadline on time. `0` when [status] is
  /// [GoalPaceStatus.unscheduled].
  final double monthlyTarget;

  /// What `current_amount` *should* be by today to stay on schedule.
  final double expectedAtToday;

  /// `current_amount − expected_at_today`. Positive when ahead,
  /// negative when behind.
  final double delta;

  factory GoalPace.fromJson(Map<String, dynamic> json) {
    return GoalPace(
      status: _statusFromString((json['status'] ?? '').toString()),
      monthlyTarget: _toDouble(
        json['monthly_target'] ?? json['monthlyTarget'],
      ),
      expectedAtToday: _toDouble(
        json['expected_at_today'] ?? json['expectedAtToday'],
      ),
      delta: _toDouble(json['delta']),
    );
  }
}

GoalPaceStatus _statusFromString(String raw) {
  switch (raw) {
    case 'ahead':
      return GoalPaceStatus.ahead;
    case 'on_track':
      return GoalPaceStatus.onTrack;
    case 'off_track':
      return GoalPaceStatus.offTrack;
    case 'inactive':
      return GoalPaceStatus.inactive;
    case 'unscheduled':
      return GoalPaceStatus.unscheduled;
    default:
      return GoalPaceStatus.unknown;
  }
}

/// Mirrors `SavingGoalResource` (`GET /saving-goals`). One record per
/// active/completed goal in the user account.
class SavingGoalModel {
  const SavingGoalModel({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.targetAmount,
    required this.currentAmount,
    required this.remainingApi,
    required this.progressPercentage,
    required this.currency,
    required this.startDate,
    required this.deadline,
    required this.status,
    required this.createdAt,
    this.pace,
  });

  final int id;
  final String title;
  final String description;
  final String icon;
  final String color;
  final double targetAmount;
  final double currentAmount;

  /// Server-clamped remaining (`max(0, target − current)`).
  final double remainingApi;

  /// Server-clamped to a maximum of 100.
  final double progressPercentage;
  final String currency;
  final String startDate;
  final String deadline;
  final String status;
  final String createdAt;

  /// Pace rollup — `null` only for older payloads that predate the
  /// `pace` field. The UI must tolerate that and render a neutral
  /// state in that case.
  final GoalPace? pace;

  /// Progress as a [0, 1] value for `CircularProgressIndicator`.
  double get progress {
    if (progressPercentage > 0) {
      return (progressPercentage / 100).clamp(0.0, 1.0);
    }
    if (targetAmount > 0) {
      return (currentAmount / targetAmount).clamp(0.0, 1.0);
    }
    return 0;
  }

  /// Display "remaining" — same fallback logic as [BudgetModel.remaining].
  double get remaining {
    if (remainingApi > 0) return remainingApi;
    return (targetAmount - currentAmount).clamp(0.0, double.infinity);
  }

  factory SavingGoalModel.fromJson(Map<String, dynamic> json) {
    final paceRaw = json['pace'];
    return SavingGoalModel(
      id: _toInt(json['id']),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      icon: (json['icon'] ?? '').toString(),
      color: (json['color'] ?? '').toString(),
      targetAmount: _toDouble(json['target_amount'] ?? json['targetAmount']),
      currentAmount:
          _toDouble(json['current_amount'] ?? json['currentAmount']),
      remainingApi: _toDouble(json['remaining']),
      progressPercentage: _toDouble(
        json['progress_percentage'] ?? json['progressPercentage'],
      ),
      currency:
          (json['currency'] ?? AppConstants.defaultCurrency).toString(),
      startDate: (json['start_date'] ?? '').toString(),
      deadline: (json['deadline'] ?? '').toString(),
      status: (json['status'] ?? 'active').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      pace: paceRaw is Map<String, dynamic>
          ? GoalPace.fromJson(paceRaw)
          : (paceRaw is Map ? GoalPace.fromJson(paceRaw.cast<String, dynamic>()) : null),
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
