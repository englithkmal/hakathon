import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../period/data/models/selected_period.dart';
import '../../../period/presentation/providers/selected_period_provider.dart';
import '../../data/models/expense_analysis_model.dart';
import '../../data/repositories/insights_repository.dart';

/// `GET /insights/expense-analysis` for the period that's currently
/// active across the rest of the app.
///
/// Watches [selectedPeriodProvider] so the analysis refetches whenever
/// the user navigates to a different month (the budget tab's pin/reset
/// flow already feeds into that provider). When the period source is
/// `unknown` (cold start, no auth) we just hand the call to the server
/// without a query so it picks its own active month.
final expenseAnalysisProvider =
    AutoDisposeFutureProvider<ExpenseAnalysisModel>((ref) async {
  final period = await ref.watch(selectedPeriodProvider.future);
  final repo = ref.watch(insightsRepositoryProvider);
  if (period.source == PeriodSource.unknown ||
      period.month <= 0 ||
      period.year <= 0) {
    return repo.loadExpenseAnalysis();
  }
  return repo.loadExpenseAnalysis(
    month: period.month,
    year: period.year,
  );
});
