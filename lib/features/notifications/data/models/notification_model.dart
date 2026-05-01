// Strongly-typed wrappers around the `notifications` payload returned by
// `GET /api/v1/notifications`. Mirrors the contract documented in the
// backend spec so the UI layer can stay schema-agnostic.

/// Frontend-facing notification kinds. Keep the enum strings in sync with
/// the backend's normalised `type` values — the backend already maps its
/// raw legacy types onto this set.
enum NotificationType {
  tip,
  goalMilestone,
  budgetAlert,
  bankSync,
  system,
  transaction,
  unknown;

  static NotificationType fromString(String? raw) {
    switch (raw) {
      case 'tip':
        return NotificationType.tip;
      case 'goal_milestone':
        return NotificationType.goalMilestone;
      case 'budget_alert':
        return NotificationType.budgetAlert;
      case 'bank_sync':
        return NotificationType.bankSync;
      case 'system':
        return NotificationType.system;
      case 'transaction':
        return NotificationType.transaction;
      default:
        return NotificationType.unknown;
    }
  }

  String get apiValue {
    switch (this) {
      case NotificationType.tip:
        return 'tip';
      case NotificationType.goalMilestone:
        return 'goal_milestone';
      case NotificationType.budgetAlert:
        return 'budget_alert';
      case NotificationType.bankSync:
        return 'bank_sync';
      case NotificationType.system:
        return 'system';
      case NotificationType.transaction:
        return 'transaction';
      case NotificationType.unknown:
        return '';
    }
  }
}

enum NotificationSeverity {
  info,
  success,
  warning,
  error;

  static NotificationSeverity fromString(String? raw) {
    switch (raw) {
      case 'success':
        return NotificationSeverity.success;
      case 'warning':
        return NotificationSeverity.warning;
      case 'error':
        return NotificationSeverity.error;
      case 'info':
      default:
        return NotificationSeverity.info;
    }
  }
}

class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.titleAr,
    required this.titleEn,
    required this.message,
    required this.messageAr,
    required this.messageEn,
    required this.icon,
    required this.isRead,
    required this.readAt,
    required this.createdAt,
    required this.deeplink,
    required this.payload,
  });

  final int id;
  final NotificationType type;
  final NotificationSeverity severity;
  final String title;
  final String titleAr;
  final String titleEn;
  final String message;
  final String messageAr;
  final String messageEn;
  final String icon;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;
  final String? deeplink;
  final Map<String, dynamic> payload;

  /// Localised title — explicit fields take precedence over the
  /// `Accept-Language`-resolved `title` so a stale cache never leaks the
  /// wrong language into the UI.
  String displayTitle(String lang) {
    if (lang == 'ar' && titleAr.isNotEmpty) return titleAr;
    if (lang == 'en' && titleEn.isNotEmpty) return titleEn;
    if (title.isNotEmpty) return title;
    return titleEn.isNotEmpty ? titleEn : titleAr;
  }

  /// Same fallback strategy as [displayTitle].
  String displayMessage(String lang) {
    if (lang == 'ar' && messageAr.isNotEmpty) return messageAr;
    if (lang == 'en' && messageEn.isNotEmpty) return messageEn;
    if (message.isNotEmpty) return message;
    return messageEn.isNotEmpty ? messageEn : messageAr;
  }

  /// Convenience wrappers around the loose `payload` map for the two
  /// rich notification kinds rendered with bespoke widgets.
  GoalMilestonePayload? get goalPayload =>
      type == NotificationType.goalMilestone
          ? GoalMilestonePayload.fromJson(payload)
          : null;

  BudgetAlertPayload? get budgetPayload =>
      type == NotificationType.budgetAlert
          ? BudgetAlertPayload.fromJson(payload)
          : null;

  TipPayload? get tipPayload =>
      type == NotificationType.tip ? TipPayload.fromJson(payload) : null;

  NotificationModel copyWith({
    bool? isRead,
    DateTime? readAt,
  }) {
    return NotificationModel(
      id: id,
      type: type,
      severity: severity,
      title: title,
      titleAr: titleAr,
      titleEn: titleEn,
      message: message,
      messageAr: messageAr,
      messageEn: messageEn,
      icon: icon,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
      deeplink: deeplink,
      payload: payload,
    );
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: _toInt(json['id']),
      type: NotificationType.fromString(json['type']?.toString()),
      severity: NotificationSeverity.fromString(json['severity']?.toString()),
      title: (json['title'] ?? '').toString(),
      titleAr: (json['title_ar'] ?? '').toString(),
      titleEn: (json['title_en'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      messageAr: (json['message_ar'] ?? '').toString(),
      messageEn: (json['message_en'] ?? '').toString(),
      icon: (json['icon'] ?? '').toString(),
      isRead: json['is_read'] == true,
      readAt: _toDate(json['read_at']),
      createdAt: _toDate(json['created_at']) ?? DateTime.now().toUtc(),
      deeplink: _nullableString(json['deeplink']),
      payload: _asMap(json['payload']),
    );
  }
}

/// Page envelope returned by `GET /notifications`.
class NotificationsPage {
  const NotificationsPage({
    required this.items,
    required this.nextCursor,
    required this.unreadCount,
  });

  final List<NotificationModel> items;
  final int? nextCursor;
  final int unreadCount;

  factory NotificationsPage.fromJson(Map<String, dynamic> json) {
    final raw = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    final items = (raw['items'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => NotificationModel.fromJson(e.cast<String, dynamic>()))
        .toList();
    return NotificationsPage(
      items: items,
      nextCursor: _nullableInt(raw['next_cursor']),
      unreadCount: _toInt(raw['unread_count']),
    );
  }
}

/// Sub-payloads — the API ships rich type-specific fields alongside the
/// generic envelope. We expose them as opt-in DTOs so consumers can stay
/// loosely-coupled to the raw map shape.

class GoalMilestonePayload {
  const GoalMilestonePayload({
    required this.goalId,
    required this.title,
    required this.titleAr,
    required this.titleEn,
    required this.progressPercentage,
    required this.currentAmount,
    required this.targetAmount,
    required this.currency,
    required this.milestone,
  });

  final int goalId;
  final String title;
  final String titleAr;
  final String titleEn;
  final double progressPercentage;
  final double currentAmount;
  final double targetAmount;
  final String currency;
  final int milestone;

  String displayTitle(String lang) {
    if (lang == 'ar' && titleAr.isNotEmpty) return titleAr;
    if (lang == 'en' && titleEn.isNotEmpty) return titleEn;
    return title;
  }

  factory GoalMilestonePayload.fromJson(Map<String, dynamic> json) {
    return GoalMilestonePayload(
      goalId: _toInt(json['goal_id']),
      title: (json['goal_title'] ?? '').toString(),
      titleAr: (json['goal_title_ar'] ?? '').toString(),
      titleEn: (json['goal_title_en'] ?? '').toString(),
      progressPercentage: _toDouble(json['goal_progress_percentage']),
      currentAmount: _toDouble(json['goal_current_amount']),
      targetAmount: _toDouble(json['goal_target_amount']),
      currency: (json['goal_currency'] ?? '').toString(),
      milestone: _toInt(json['milestone']),
    );
  }
}

class BudgetAlertPayload {
  const BudgetAlertPayload({
    required this.budgetId,
    required this.overrunPercentage,
    required this.categoryNameAr,
    required this.categoryNameEn,
    required this.percentage,
    required this.spent,
    required this.allocated,
  });

  final int budgetId;
  final double overrunPercentage;
  final String categoryNameAr;
  final String categoryNameEn;
  final double percentage;
  final double spent;
  final double allocated;

  String displayCategory(String lang) {
    if (lang == 'ar' && categoryNameAr.isNotEmpty) return categoryNameAr;
    if (lang == 'en' && categoryNameEn.isNotEmpty) return categoryNameEn;
    return categoryNameEn.isNotEmpty ? categoryNameEn : categoryNameAr;
  }

  factory BudgetAlertPayload.fromJson(Map<String, dynamic> json) {
    return BudgetAlertPayload(
      budgetId: _toInt(json['budget_id']),
      overrunPercentage: _toDouble(json['budget_overrun_percentage']),
      categoryNameAr: (json['budget_category_name_ar'] ?? '').toString(),
      categoryNameEn: (json['budget_category_name_en'] ?? '').toString(),
      percentage: _toDouble(json['percentage']),
      spent: _toDouble(json['spent']),
      allocated: _toDouble(json['allocated']),
    );
  }
}

class TipPayload {
  const TipPayload({required this.tipId, required this.categoryId});

  final int tipId;
  final int categoryId;

  factory TipPayload.fromJson(Map<String, dynamic> json) {
    return TipPayload(
      tipId: _toInt(json['tip_id']),
      categoryId: _toInt(json['category_id']),
    );
  }
}

// ─────────────────────── Internal parsing helpers ───────────────────────

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return const <String, dynamic>{};
}

int _toInt(Object? value, {int fallback = 0}) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? fallback;
}

int? _nullableInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double _toDouble(Object? value) {
  if (value == null) return 0;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

DateTime? _toDate(Object? value) {
  if (value == null) return null;
  final raw = value.toString();
  if (raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}

String? _nullableString(Object? value) {
  if (value == null) return null;
  final s = value.toString();
  return s.isEmpty ? null : s;
}
