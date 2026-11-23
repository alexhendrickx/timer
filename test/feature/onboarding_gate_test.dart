import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timer/core/routing/app_router.dart';
import 'package:timer/core/services/database/app_database.dart';
import 'package:timer/feature/activities/data/activity_repository.dart';
import 'package:timer/feature/onboarding/data/onboarding_state.dart';

void main() {
  late AppDatabase db;
  late ActivityRepository activities;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    activities = ActivityRepository(db);
  });

  tearDown(() => db.close());

  Future<bool?> donePref() async =>
      (await SharedPreferences.getInstance()).getBool('onboarding_done');

  test('shows on an empty database with no pref', () async {
    expect(await shouldShowOnboarding(activities), true);
    expect(await donePref(), isNull);
  });

  test('does not show once onboarding_done is set', () async {
    await markOnboardingDone();

    expect(await donePref(), true);
    expect(await shouldShowOnboarding(activities), false);
  });

  test('does not show when an activity exists, and sets the pref', () async {
    await activities.create(name: 'Client X');

    expect(await shouldShowOnboarding(activities), false);
    expect(await donePref(), true);
  });

  test('an archived activity counts as existing', () async {
    final id = await activities.create(name: 'Old client');
    await activities.archive(id);
    expect(await activities.activeActivities(), isEmpty);

    expect(await shouldShowOnboarding(activities), false);
  });

  test('a soft-deleted activity counts as existing', () async {
    final id = await activities.create(name: 'Gone');
    await activities.delete(id);
    expect(await activities.activeActivities(), isEmpty);

    expect(await shouldShowOnboarding(activities), false);
  });

  test('stays hidden after the database later becomes empty', () async {
    await activities.create(name: 'Client X');
    expect(await shouldShowOnboarding(activities), false);

    // A changed or missing data folder: a brand-new, empty database.
    await db.close();
    db = AppDatabase(NativeDatabase.memory());
    final emptyActivities = ActivityRepository(db);
    expect(await emptyActivities.hasAnyActivity(), false);

    expect(await shouldShowOnboarding(emptyActivities), false);
  });

  test('does not show when the data folder fell back', () async {
    expect(
      await shouldShowOnboarding(activities, dataFolderFellBack: true),
      false,
    );
    expect(await donePref(), isNull);
  });

  test('hasAnyActivity is false on an empty table', () async {
    expect(await activities.hasAnyActivity(), false);

    await activities.create(name: 'Client X');
    expect(await activities.hasAnyActivity(), true);
  });

  test('buildAppRouter starts at / by default and at the given location', () {
    expect(
      buildAppRouter().routeInformationProvider.value.uri.toString(),
      '/',
    );
    expect(
      buildAppRouter(initialLocation: '/onboarding')
          .routeInformationProvider
          .value
          .uri
          .toString(),
      '/onboarding',
    );
  });
}
