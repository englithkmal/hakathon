import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/user_currency_provider.dart';
import '../../../home/presentation/widgets/home_app_bar.dart' show HomeUserAvatar;
import '../../../notifications/presentation/widgets/notifications_bell.dart';

/// "الحساب" — fourth tab, mirrors the Figma profile design:
///
/// • Brand AppBar (logo on the start, bell + avatar on the end),
/// • Hero card with the user's avatar, name, email and member badges,
/// • Linked banks list (placeholder until the bank-linking API ships),
/// • Primary currency picker — wired to `PUT /auth/profile`,
/// • App preferences (expense alerts, dark mode, language),
/// • Logout CTA + version footer.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  /// Local-only toggle for the "expense alerts" switch — there is no
  /// backend endpoint for it yet, so we keep the UX consistent with
  /// the design without persisting the flag across launches.
  bool _expenseAlertsOn = true;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authProvider);
    final user = auth is AuthAuthenticated ? auth.user : null;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: _ProfileAppBar(user: user),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.mobileMargin,
            AppSpacing.md,
            AppSpacing.mobileMargin,
            MediaQuery.paddingOf(context).bottom + AppSpacing.xl + 80,
          ),
          children: [
            _ProfileHeroCard(user: user),
            const SizedBox(height: AppSpacing.md),
            _BanksCard(),
            const SizedBox(height: AppSpacing.md),
            const _CurrencyCard(),
            const SizedBox(height: AppSpacing.md),
            _PreferencesCard(
              expenseAlertsOn: _expenseAlertsOn,
              onExpenseAlertsChanged: (v) =>
                  setState(() => _expenseAlertsOn = v),
            ),
            const SizedBox(height: AppSpacing.lg),
            _LogoutButton(onPressed: () => _confirmLogout(context, ref)),
            const SizedBox(height: AppSpacing.md),
            const _VersionFooter(),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr(AppStrings.profileLogout)),
        content: Text(context.tr(AppStrings.profileLogoutConfirm)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.tr(AppStrings.profileLogout)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authProvider.notifier).logout();
    }
  }
}

// ───────────────────────────── App bar ─────────────────────────────

class _ProfileAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ProfileAppBar({required this.user});

  final UserModel? user;

  @override
  Size get preferredSize => const Size.fromHeight(AppDimens.appBarHeight);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: AppDimens.appBarHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.mobileMargin,
            ),
            child: Row(
              children: [
                // The Waffer wordmark sits at the start (right in RTL).
                Text(
                  'وفّر',
                  textDirection: TextDirection.rtl,
                  style: AppTextStyles.headlineMd(
                    color: scheme.primary,
                  ).copyWith(fontWeight: FontWeight.w800, fontSize: 22),
                ),
                const Spacer(),
                NotificationsBell(
                  iconColor: scheme.onSurface,
                ),
                const SizedBox(width: AppSpacing.xs),
                HomeUserAvatar(user: user),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────── Hero ───────────────────────────────

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({required this.user});

  final UserModel? user;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final displayName = (user?.name?.trim().isNotEmpty ?? false)
        ? user!.name!.trim()
        : (user?.email ?? '—');
    final email = user?.email ?? '';

    return _SectionCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.lg,
          horizontal: AppSpacing.md,
        ),
        child: Column(
          children: [
            _ProfileAvatar(user: user),
            const SizedBox(height: AppSpacing.md),
            Text(
              displayName,
              style: AppTextStyles.headlineMd(
                color: scheme.onSurface,
              ).copyWith(fontWeight: FontWeight.w800, fontSize: 22),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (email.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                email,
                textDirection: TextDirection.ltr,
                style: AppTextStyles.bodyMd(color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Badge(
                  label: context.tr(AppStrings.profileBadgePlatinum),
                  filled: true,
                ),
                const SizedBox(width: AppSpacing.sm),
                _Badge(
                  label: context.tr(AppStrings.profileBadgeVerified),
                  filled: false,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.user});

  final UserModel? user;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = user?.avatarUrl;
    final initial = _initialLetter(user);

    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        children: [
          // Outer ring + inner avatar.
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.85),
                width: 2.5,
              ),
            ),
            padding: const EdgeInsets.all(3),
            child: ClipOval(
              child: (url != null && url.isNotEmpty)
                  ? Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _fallback(context, initial),
                    )
                  : _fallback(context, initial),
            ),
          ),
          // Edit pencil pill at the bottom-end.
          PositionedDirectional(
            bottom: 0,
            end: 0,
            child: Material(
              color: scheme.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () {
                  // TODO(profile): wire up "edit photo" once the
                  // backend endpoint for avatar uploads ships.
                },
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.edit_rounded,
                    size: 14,
                    color: scheme.onPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback(BuildContext context, String letter) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.primaryContainer,
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: AppTextStyles.headlineLg(
          color: scheme.onPrimaryContainer,
        ).copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }

  String _initialLetter(UserModel? user) {
    final name = user?.name?.trim();
    if (name != null && name.isNotEmpty) {
      final it = name.runes.iterator;
      if (it.moveNext()) {
        return String.fromCharCode(it.current).toUpperCase();
      }
    }
    return '?';
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.filled});

  final String label;

  /// `true` for the saturated primary pill ("عضو بلاتيني"), `false`
  /// for the outlined / lighter pill ("موثّق").
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = filled
        ? scheme.primary
        : scheme.primaryContainer.withValues(alpha: 0.55);
    final fg = filled ? scheme.onPrimary : scheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelMd(color: fg)
            .copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ───────────────────────────── Banks card ─────────────────────────────

class _BanksCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _SectionCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(
              icon: Icons.account_balance_outlined,
              title: context.tr(AppStrings.profileBanksTitle),
              actionLabel: context.tr(AppStrings.profileBanksAdd),
              onActionTap: () {
                // TODO(profile): launch the bank linking flow once
                // `/banks` API is available.
              },
            ),
            const SizedBox(height: AppSpacing.md),
            _BankRow(
              name: context.tr(AppStrings.profileBanksSampleAlrajhi),
              connected: true,
              onTap: () {},
            ),
            const SizedBox(height: AppSpacing.sm),
            _BankRow(
              name: context.tr(AppStrings.profileBanksSampleAlahli),
              connected: false,
              onTap: () {},
            ),
            // Hairline below the list; matches the Figma divider so
            // the card breathes against the next section.
            const SizedBox(height: AppSpacing.xs),
            Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _BankRow extends StatelessWidget {
  const _BankRow({
    required this.name,
    required this.connected,
    required this.onTap,
  });

  final String name;
  final bool connected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconBg = connected
        ? scheme.primaryContainer.withValues(alpha: 0.45)
        : scheme.surfaceContainerHigh;
    final iconColor = connected ? scheme.primary : scheme.outline;
    final nameColor = connected ? scheme.onSurface : scheme.outline;

    return InkWell(
      borderRadius: AppRadius.brMd,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Icon(
              Icons.chevron_left_rounded,
              color: scheme.outline,
            ),
            const Spacer(),
            // Status pill — only shown for the "غير متصل" row in the
            // Figma reference; connected rows get a chevron only.
            if (!connected)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: Text(
                  context.tr(AppStrings.profileBanksDisconnected),
                  style: AppTextStyles.labelSm(color: scheme.error),
                ),
              ),
            Text(
              name,
              style: AppTextStyles.bodyLg(color: nameColor)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: AppRadius.brSm,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.credit_card_outlined,
                color: iconColor,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────── Currency card ─────────────────────────────

class _CurrencyCard extends ConsumerWidget {
  const _CurrencyCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final currency = ref.watch(userCurrencyProvider);
    final code = currency;
    final name = context.tr(_currencyNameKey(code));

    return _SectionCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(
              icon: Icons.currency_exchange_rounded,
              title: context.tr(AppStrings.profileCurrency),
            ),
            const SizedBox(height: AppSpacing.sm),
            InkWell(
              borderRadius: AppRadius.brMd,
              onTap: () => _pickCurrency(context, ref, code),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: AppRadius.brMd,
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Stack(
                  children: [
                    // Hint label tucked into the top-end corner.
                    PositionedDirectional(
                      top: 0,
                      end: 0,
                      child: Text(
                        context.tr(AppStrings.profileCurrencyHint),
                        style: AppTextStyles.labelSm(
                          color: scheme.onSurfaceVariant,
                        ).copyWith(fontSize: 11),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.md),
                      child: Row(
                        children: [
                          Icon(
                            Icons.expand_more_rounded,
                            color: scheme.primary,
                          ),
                          const Spacer(),
                          Directionality(
                            textDirection: TextDirection.rtl,
                            child: Text(
                              '$name ($code)',
                              style: AppTextStyles.headlineSm(
                                color: scheme.primary,
                              ).copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the currency picker bottom sheet, then `PUT`s the choice
  /// to `/auth/profile` so the change syncs server-side.
  Future<void> _pickCurrency(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    // Capture context-bound values up front so we don't reach across
    // an async gap and trigger `use_build_context_synchronously`.
    final messenger = ScaffoldMessenger.of(context);
    final localizedSuccess = context.tr(AppStrings.profileCurrencyUpdated);
    final localizedError = context.tr(AppStrings.profileCurrencyError);
    final pickerTitle = context.tr(AppStrings.profileCurrencyPickTitle);
    final scheme = Theme.of(context).colorScheme;

    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: Text(
                    pickerTitle,
                    style: Theme.of(sheetCtx).textTheme.titleMedium,
                  ),
                ),
                const Divider(height: 1),
                ...AppConstants.supportedCurrencies.map((c) {
                  final selected = c == current;
                  final name = sheetCtx.tr(_currencyNameKey(c));
                  return ListTile(
                    leading: Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: selected
                          ? Theme.of(sheetCtx).colorScheme.primary
                          : Theme.of(sheetCtx).colorScheme.outline,
                    ),
                    title: Text(
                      '$name ($c)',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onTap: () => Navigator.of(sheetCtx).pop(c),
                  );
                }),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        );
      },
    );

    if (picked == null || picked == current) return;

    // Changing the primary currency is a destructive operation: existing
    // amounts aren't auto-converted server-side, and any month that's
    // already in progress will mix two currencies in the same totals.
    // Surface the consequences in a dedicated confirmation dialog
    // before we hit `PUT /auth/profile`.
    if (!context.mounted) return;
    final confirmed = await _showCurrencyChangeConfirm(
      context,
      currentCode: current,
      pickedCode: picked,
    );
    if (confirmed != true) return;

    final failure =
        await ref.read(authProvider.notifier).updateProfile(currency: picked);
    if (failure == null) {
      messenger.showSnackBar(SnackBar(content: Text(localizedSuccess)));
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text('$localizedError: ${failure.message}')),
      );
    }
  }

  /// Shows the polished "are you sure?" dialog for currency changes.
  ///
  /// Returns `true` only when the user explicitly taps the destructive
  /// CTA. Tapping outside, the close button, or "Cancel" all return
  /// `false` so the caller can short-circuit safely.
  Future<bool?> _showCurrencyChangeConfirm(
    BuildContext context, {
    required String currentCode,
    required String pickedCode,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CurrencyChangeDialog(
        currentCode: currentCode,
        pickedCode: pickedCode,
      ),
    );
  }
}

// ─────────────────────── Currency change dialog ───────────────────────

/// Destructive-action confirmation shown before `PUT /auth/profile`
/// changes the primary currency.
///
/// Layout (top → bottom):
///   • Centered amber warning icon inside a soft background circle.
///   • Title.
///   • "OLD → NEW" currency comparison row (chips with the ISO code and
///     the localised long name).
///   • Intro paragraph.
///   • Three bulleted reasons explaining the consequences.
///   • "Recommendation" callout (soft amber container) suggesting the
///     change be deferred to the start of next month.
///   • Cancel / proceed actions.
class _CurrencyChangeDialog extends StatelessWidget {
  const _CurrencyChangeDialog({
    required this.currentCode,
    required this.pickedCode,
  });

  final String currentCode;
  final String pickedCode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final calloutBg = isDark
        ? AppColors.amber900.withValues(alpha: 0.25)
        : AppColors.amber50;
    final calloutFg = isDark ? AppColors.amber100 : AppColors.amber900;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.brLg),
      backgroundColor: scheme.surface,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.amber100,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.amber700,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                context.tr(AppStrings.profileCurrencyConfirmTitle),
                textAlign: TextAlign.center,
                style: AppTextStyles.headlineSm(color: scheme.onSurface)
                    .copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.md),
              _CurrencyHopRow(
                currentCode: currentCode,
                pickedCode: pickedCode,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                context.tr(AppStrings.profileCurrencyConfirmIntro),
                style: AppTextStyles.bodySm(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.sm + 2),
              _ReasonBullet(
                text: context.tr(AppStrings.profileCurrencyConfirmReason1),
              ),
              _ReasonBullet(
                text: context.tr(AppStrings.profileCurrencyConfirmReason2),
              ),
              _ReasonBullet(
                text: context.tr(AppStrings.profileCurrencyConfirmReason3),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm + 2,
                ),
                decoration: BoxDecoration(
                  color: calloutBg,
                  borderRadius: AppRadius.brSm,
                  border: Border.all(
                    color: AppColors.amber500.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 18,
                      color: calloutFg,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        context.tr(
                          AppStrings.profileCurrencyConfirmRecommended,
                        ),
                        style: AppTextStyles.bodySm(color: calloutFg)
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: scheme.onSurface,
                        side: BorderSide(color: scheme.outlineVariant),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm + 4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        context.tr(
                          AppStrings.profileCurrencyConfirmCancel,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm + 2),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.error,
                        foregroundColor: scheme.onError,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm + 4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        context.tr(
                          AppStrings.profileCurrencyConfirmProceed,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrencyHopRow extends StatelessWidget {
  const _CurrencyHopRow({
    required this.currentCode,
    required this.pickedCode,
  });

  final String currentCode;
  final String pickedCode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CurrencyChip(code: currentCode, muted: true),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Icon(
            // Direction-aware "from → to" arrow so RTL also reads
            // start-to-end naturally.
            Directionality.of(context) == TextDirection.rtl
                ? Icons.arrow_back_rounded
                : Icons.arrow_forward_rounded,
            color: scheme.onSurfaceVariant,
            size: 22,
          ),
        ),
        _CurrencyChip(code: pickedCode, muted: false),
      ],
    );
  }
}

class _CurrencyChip extends StatelessWidget {
  const _CurrencyChip({required this.code, required this.muted});

  final String code;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = muted
        ? scheme.surfaceContainerHigh
        : scheme.primary.withValues(alpha: 0.12);
    final fg = muted ? scheme.onSurfaceVariant : scheme.primary;
    final name = context.tr(_currencyNameKey(code));
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (muted ? scheme.outlineVariant : scheme.primary)
              .withValues(alpha: muted ? 0.5 : 0.35),
        ),
      ),
      child: Column(
        children: [
          // Use an explicit LTR Directionality so the ISO code (always
          // Latin) doesn't flip in Arabic locales.
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              code,
              style: AppTextStyles.headlineSm(color: fg)
                  .copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            name,
            style: AppTextStyles.labelSm(color: fg.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }
}

class _ReasonBullet extends StatelessWidget {
  const _ReasonBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(
              top: 6,
              end: AppSpacing.sm + 2,
            ),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: scheme.error,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySm(color: scheme.onSurface)
                  .copyWith(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

// Maps a currency ISO code to the matching translation key. Falling
// back to the SAR label keeps the UI stable if the backend ever
// returns a code we don't have a localised name for.
String _currencyNameKey(String code) {
  switch (code.toUpperCase()) {
    case 'JOD':
      return AppStrings.currencyNameJod;
    case 'USD':
      return AppStrings.currencyNameUsd;
    case 'AED':
      return AppStrings.currencyNameAed;
    case 'EUR':
      return AppStrings.currencyNameEur;
    case 'SAR':
    default:
      return AppStrings.currencyNameSar;
  }
}

// ─────────────────────────── Preferences card ───────────────────────────

class _PreferencesCard extends ConsumerWidget {
  const _PreferencesCard({
    required this.expenseAlertsOn,
    required this.onExpenseAlertsChanged,
  });

  final bool expenseAlertsOn;
  final ValueChanged<bool> onExpenseAlertsChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final themeMode = ref.watch(themeProvider);
    final locale = ref.watch(localeProvider);
    final auth = ref.watch(authProvider);
    final emailHint = auth is AuthAuthenticated ? auth.user?.email ?? '' : '';

    return _SectionCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(
              icon: null,
              title: context.tr(AppStrings.profilePrefsTitle),
              centered: true,
            ),
            const SizedBox(height: AppSpacing.sm),
            _PrefRow(
              icon: Icons.notifications_active_outlined,
              title: context.tr(AppStrings.profilePrefsExpenseAlerts),
              subtitle: emailHint,
              trailing: Switch(
                value: expenseAlertsOn,
                onChanged: onExpenseAlertsChanged,
              ),
            ),
            Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.45),
            ),
            _PrefRow(
              icon: Icons.dark_mode_outlined,
              title: context.tr(AppStrings.profileDarkMode),
              subtitle: emailHint,
              trailing: Switch(
                value: themeMode == ThemeMode.dark,
                onChanged: (_) => ref.read(themeProvider.notifier).toggle(),
              ),
            ),
            Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.45),
            ),
            _PrefRow(
              icon: Icons.language_outlined,
              title: context.tr(AppStrings.profileLanguage),
              subtitle: emailHint,
              onTap: () => ref.read(localeProvider.notifier).toggle(),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    locale.languageCode == 'ar' ? 'العربية' : 'English',
                    style: AppTextStyles.labelMd(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_left_rounded,
                    color: scheme.outline,
                    size: 18,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrefRow extends StatelessWidget {
  const _PrefRow({
    required this.icon,
    required this.title,
    required this.trailing,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.brMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm + 2,
          horizontal: 4,
        ),
        child: Row(
          children: [
            trailing,
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyLg(color: scheme.onSurface)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    textDirection: TextDirection.ltr,
                    style: AppTextStyles.labelSm(color: scheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: AppRadius.brSm,
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Logout + version ───────────────────────────

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onPressed,
      borderRadius: AppRadius.brMd,
      child: Container(
        height: AppDimens.buttonHeight + 4,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: scheme.errorContainer.withValues(alpha: 0.35),
          borderRadius: AppRadius.brMd,
          border: Border.all(color: scheme.error.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(Icons.chevron_left_rounded, color: scheme.error),
            const Spacer(),
            Text(
              context.tr(AppStrings.profileLogout),
              style: AppTextStyles.labelLg(color: scheme.error)
                  .copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.logout_rounded, color: scheme.error, size: 20),
          ],
        ),
      ),
    );
  }
}

class _VersionFooter extends StatelessWidget {
  const _VersionFooter();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Hard-coded for now to match the Figma design. Once the app
    // pubspec version becomes a moving target we can replace this
    // with `package_info_plus` lookups.
    const version = '2.4.0';
    return Center(
      child: Text(
        '${context.tr(AppStrings.profileAppVersion)} $version',
        style: AppTextStyles.labelSm(color: scheme.outline),
      ),
    );
  }
}

// ───────────────────────────── Shared bits ─────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.brLg,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.icon,
    this.actionLabel,
    this.onActionTap,
    this.centered = false,
  });

  final String title;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onActionTap;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final titleRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: AppTextStyles.headlineSm(color: scheme.onSurface)
              .copyWith(fontWeight: FontWeight.w800),
        ),
        if (icon != null) ...[
          const SizedBox(width: AppSpacing.xs),
          Icon(icon, color: scheme.primary, size: 18),
        ],
      ],
    );

    if (centered && actionLabel == null) {
      return SizedBox(
        height: 28,
        child: Center(child: titleRow),
      );
    }

    // Title centred, action floats to the start (i.e. far left in
    // RTL). A `Stack` avoids the action stealing horizontal space
    // from the title or pushing it off-centre on narrow widths.
    return SizedBox(
      height: 28,
      child: Stack(
        alignment: Alignment.center,
        children: [
          titleRow,
          if (actionLabel != null)
            PositionedDirectional(
              start: 0,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onActionTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Text(
                    actionLabel!,
                    style: AppTextStyles.labelMd(color: scheme.primary)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
