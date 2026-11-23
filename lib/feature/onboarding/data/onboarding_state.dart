import 'package:shared_preferences/shared_preferences.dart';

import '../../activities/data/activity_repository.dart';

const String onboardingDoneKey = 'onboarding_done';

/// Whether this launch starts on the first-run flow. True only when the pref
/// is unset, the activities table has no row of any kind, and the data
/// folder did not fall back. Seeing a row once sets the pref, so a later
/// empty database (changed or missing data folder) does not bring it back.
Future<bool> shouldShowOnboarding(
  ActivityRepository activities, {
  bool dataFolderFellBack = false,
}) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(onboardingDoneKey) ?? false) return false;
  if (await activities.hasAnyActivity()) {
    await prefs.setBool(onboardingDoneKey, true);
    return false;
  }
  return !dataFolderFellBack;
}

/// Called on "Skip setup" and on "Done".
Future<void> markOnboardingDone() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(onboardingDoneKey, true);
}
