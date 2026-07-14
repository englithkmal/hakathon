import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/storage/storage_keys.dart';

/// Whether the user has completed the onboarding walkthrough.
enum OnboardingStatus { pending, done }

class OnboardingNotifier extends Notifier<OnboardingStatus> {
  @override
  OnboardingStatus build() {
    _restore();
    return OnboardingStatus.pending;
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool(StorageKeys.onboardingDone) ?? false;
    if (done) {
      state = OnboardingStatus.done;
    }
  }

  /// Marks the onboarding as completed and persists the choice.
  Future<void> complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.onboardingDone, true);
    state = OnboardingStatus.done;
  }

  /// Resets the flag, mainly useful for testing or a "view tour" action.
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(StorageKeys.onboardingDone);
    state = OnboardingStatus.pending;
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingNotifier, OnboardingStatus>(
  OnboardingNotifier.new,
);
