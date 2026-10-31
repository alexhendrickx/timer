import 'package:drift/drift.dart';

/// A named thing a session is tagged with — a client or personal category.
/// Deleting one that has sessions is not allowed (archived instead; spec D7).
class Activities extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();

  /// Optional swatch stored as an ARGB int.
  IntColumn get color => integer().nullable()();

  /// Optional billing rate; when set, exports show amounts.
  RealColumn get hourlyRate => real().nullable()();

  /// Plain currency label (e.g. "EUR"); no conversion logic.
  TextColumn get currencyLabel => text().nullable()();

  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
}

/// A recorded work session. Belongs wholly to its start day (spec D5).
/// The exact [durationSeconds] is the stored truth; rounding is a view only.
class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// FK → Activities.id. Restrict delete so an activity with sessions cannot
  /// be hard-deleted (it is archived instead; spec D7).
  IntColumn get activityId =>
      integer().references(Activities, #id, onDelete: KeyAction.restrict)();

  /// The day the session started.
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get startTime => dateTime()();

  /// Null while the timer is running.
  DateTimeColumn get endTime => dateTime().nullable()();

  IntColumn get durationSeconds => integer().withDefault(const Constant(0))();
  TextColumn get note => text().nullable()();

  /// Periodically persisted while running, for crash/quit resume (spec D2).
  DateTimeColumn get lastSeenAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}
