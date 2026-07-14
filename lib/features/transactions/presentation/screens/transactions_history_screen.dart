import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/user_currency_provider.dart';
import '../providers/transactions_provider.dart';
import '../widgets/add_transaction_card.dart';
import '../widgets/transaction_history_section.dart';
import '../widgets/transactions_app_bar.dart';

class TransactionsHistoryScreen extends ConsumerWidget {
  const TransactionsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authProvider);
    final user = auth is AuthAuthenticated ? auth.user : null;
    final asyncTxs = ref.watch(transactionsProvider);
    final lang = Localizations.localeOf(context).languageCode;
    // `userCurrencyProvider` reads `dashboard.currency` first and
    // falls back to the cached `auth.user.currency` — exactly the
    // chain we want for the inline add-transaction card.
    final currency = ref.watch(userCurrencyProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: TransactionsAppBar(
        user: user,
        // `push` keeps the Transactions tab on the stack so the system
        // back gesture returns here instead of exiting the app.
        onNotificationsTap: () => context.push(RouteNames.notificationsPath),
      ),
      // The whole body is one scrollable surface so the inline add-card
      // and history list flow together. This avoids any RenderFlex
      // overflow when the system keyboard opens for the note field —
      // the surface just scrolls instead of the layout collapsing.
      body: RefreshIndicator(
        onRefresh: () => ref.read(transactionsProvider.notifier).refresh(),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimens.maxContentWidth,
            ),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.zero,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.mobileMargin,
                    AppSpacing.md,
                    AppSpacing.mobileMargin,
                    AppSpacing.md,
                  ),
                  child: AddTransactionCard(currency: currency),
                ),
                _HistoryBody(asyncTxs: asyncTxs, lang: lang),
                SizedBox(
                  height: MediaQuery.paddingOf(context).bottom +
                      AppSpacing.xl +
                      80,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryBody extends ConsumerWidget {
  const _HistoryBody({required this.asyncTxs, required this.lang});

  final AsyncValue asyncTxs;
  final String lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return asyncTxs.when(
      data: (txState) {
        final items = (txState.items as List).cast<dynamic>();
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.mobileMargin,
          ),
          child: TransactionHistorySection(
            transactions: items.cast(),
            languageCode: lang,
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => _ErrorBlock(),
    );
  }
}

class _ErrorBlock extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.mobileMargin,
        AppSpacing.xl,
        AppSpacing.mobileMargin,
        AppSpacing.md,
      ),
      child: Column(
        children: [
          Text(
            context.tr(AppStrings.transactionsLoadFailed),
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMd(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: () => ref.invalidate(transactionsProvider),
            child: Text(context.tr(AppStrings.commonRetry)),
          ),
        ],
      ),
    );
  }
}
