import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/custom_button.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_dots.dart';
import '../widgets/onboarding_illustration.dart';

/// Three-step walkthrough that introduces WafferApp's value props before the
/// user reaches the auth flow.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  bool _finishing = false;

  static const _pages = <_OnboardingPageData>[
    _OnboardingPageData(
      icon: Icons.receipt_long_rounded,
      titleKey: AppStrings.onboarding1Title,
      bodyKey: AppStrings.onboarding1Body,
    ),
    _OnboardingPageData(
      icon: Icons.savings_rounded,
      titleKey: AppStrings.onboarding2Title,
      bodyKey: AppStrings.onboarding2Body,
    ),
    _OnboardingPageData(
      icon: Icons.insights_rounded,
      titleKey: AppStrings.onboarding3Title,
      bodyKey: AppStrings.onboarding3Body,
    ),
  ];

  bool get _isLast => _currentPage == _pages.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _onPrimaryAction() async {
    if (_isLast) {
      await _finish();
      return;
    }
    await _pageController.nextPage(
      duration: AppConstants.defaultAnimation,
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    await ref.read(onboardingProvider.notifier).complete();
    // Router redirect listens to onboardingProvider and pushes /login.
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    // In RTL, the "next" arrow visually points left.
    final nextIcon =
        isRtl ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _OnboardingHeader(
              showSkip: !_isLast && !_finishing,
              onSkip: _finish,
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) =>
                    setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return _OnboardingPage(data: page);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.mobileMargin,
                AppSpacing.md,
                AppSpacing.mobileMargin,
                AppSpacing.lg,
              ),
              child: Column(
                children: [
                  OnboardingDots(
                    count: _pages.length,
                    currentIndex: _currentPage,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  CustomButton(
                    label: context.tr(
                      _isLast
                          ? AppStrings.onboardingGetStarted
                          : AppStrings.onboardingNext,
                    ),
                    trailingIcon: _isLast ? null : nextIcon,
                    isLoading: _finishing && _isLast,
                    onPressed: _finishing ? null : _onPrimaryAction,
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

class _OnboardingHeader extends StatelessWidget {
  const _OnboardingHeader({
    required this.showSkip,
    required this.onSkip,
  });

  final bool showSkip;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.mobileMargin,
        AppSpacing.sm,
        AppSpacing.mobileMargin,
        0,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: AppRadius.brSm,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.account_balance_rounded,
              size: AppIconSize.md,
              color: scheme.primary,
            ),
          ),
          const Spacer(),
          AnimatedOpacity(
            duration: AppConstants.shortAnimation,
            opacity: showSkip ? 1 : 0,
            child: TextButton(
              onPressed: showSkip ? onSkip : null,
              style: TextButton.styleFrom(
                foregroundColor: scheme.onSurfaceVariant,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
              child: Text(
                context.tr(AppStrings.onboardingSkip),
                style: AppTextStyles.labelLg(color: scheme.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data});

  final _OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Cap the illustration to a sensible size so very tall phones don't
        // blow it up, and so the text still fits comfortably below.
        final illustrationSize = (constraints.maxHeight * 0.45)
            .clamp(180.0, 300.0);

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.mobileMargin,
            vertical: AppSpacing.lg,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - AppSpacing.lg * 2,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: illustrationSize,
                    maxHeight: illustrationSize,
                  ),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: OnboardingIllustration(icon: data.icon),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  context.tr(data.titleKey),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headlineXl(color: scheme.primary),
                ),
                const SizedBox(height: AppSpacing.md),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Text(
                    context.tr(data.bodyKey),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyLg(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.icon,
    required this.titleKey,
    required this.bodyKey,
  });

  final IconData icon;
  final String titleKey;
  final String bodyKey;
}
