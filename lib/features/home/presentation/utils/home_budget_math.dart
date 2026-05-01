import '../../data/models/dashboard_model.dart';

/// Spending number for the "Spending vs Budget" card.
///
/// Order of preference (matches Filament admin when `budget.exists`):
///   1. `budget.total_spent`
///   2. sum of `budget.categories[].spent`
///   3. `summary.expenses` (transactions-only fallback)
double homeBudgetSpent(DashboardModel d) {
  if (d.hasBudget) return d.budget.totalSpent;
  return d.summary.expenses;
}

/// Total cap for the progress bar.
///
///   1. `budget.total_amount`
///   2. `summary.monthly_income` (so the bar still has scale before a
///      budget is set)
///   3. expenses * 1.2 (last-resort visual fallback)
double homeBudgetTotal(DashboardModel d) {
  if (d.hasBudget) return d.budget.totalAmount;
  final mi = d.summary.monthlyIncome;
  if (mi > 0) return mi;
  final ex = d.summary.expenses;
  return ex > 0 ? ex * 1.2 : 1;
}

/// Remaining shown under the bar — prefer the API field so it matches
/// `BudgetResource.remaining` exactly.
double homeBudgetRemaining(DashboardModel d) {
  if (d.hasBudget) return d.budget.remaining;
  final total = homeBudgetTotal(d);
  return (total - homeBudgetSpent(d)).clamp(0.0, double.infinity);
}
