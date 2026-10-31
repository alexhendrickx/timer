import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Resolves where the SQLite database file lives. The user may choose a folder
/// (persisted in [SharedPreferences]); otherwise it defaults to
/// `<Documents>/Timer`. If a previously chosen folder is gone or unwritable
/// (e.g. an ejected drive), it falls back to the default and records why — the
/// app surfaces that instead of crashing.
class StorageLocationService {
  StorageLocationService({SharedPreferences? prefs, Directory? documentsDir})
      : _injectedPrefs = prefs,
        _injectedDocumentsDir = documentsDir;

  static const _dataFolderKey = 'data_folder';
  static const _dbFileName = 'timer.sqlite';
  static const _defaultSubfolder = 'Timer';

  final SharedPreferences? _injectedPrefs;
  final Directory? _injectedDocumentsDir;

  String? _currentFolder;
  String? _lastFallbackReason;

  /// The folder actually in use after the last [resolveDbPath], or null before.
  String? get currentFolder => _currentFolder;

  /// Non-null when the last [resolveDbPath] had to fall back to the default
  /// because the chosen folder was missing or unwritable.
  String? get lastFallbackReason => _lastFallbackReason;

  Future<SharedPreferences> _prefs() async =>
      _injectedPrefs ?? await SharedPreferences.getInstance();

  Future<Directory> _documentsDir() async =>
      _injectedDocumentsDir ?? await getApplicationDocumentsDirectory();

  /// Persists the user's chosen data folder.
  Future<void> setDataFolder(String folderPath) async {
    final prefs = await _prefs();
    await prefs.setString(_dataFolderKey, folderPath);
  }

  /// Returns `<folder>/timer.sqlite`, creating the folder as needed. Falls back
  /// to `<Documents>/Timer` (and sets [lastFallbackReason]) if a chosen folder
  /// is missing or unwritable.
  Future<String> resolveDbPath() async {
    _lastFallbackReason = null;
    final prefs = await _prefs();
    final chosen = prefs.getString(_dataFolderKey);

    if (chosen != null) {
      final reason = _unusableReason(chosen);
      if (reason == null) {
        _currentFolder = chosen;
        return p.join(chosen, _dbFileName);
      }
      _lastFallbackReason =
          'Chosen folder "$chosen" is unavailable ($reason). Using the default folder.';
    }

    final defaultFolder =
        p.join((await _documentsDir()).path, _defaultSubfolder);
    await Directory(defaultFolder).create(recursive: true);
    _currentFolder = defaultFolder;
    return p.join(defaultFolder, _dbFileName);
  }

  /// null when [folderPath] exists and is writable; otherwise a short reason.
  String? _unusableReason(String folderPath) {
    final dir = Directory(folderPath);
    if (!dir.existsSync()) return 'not found';
    try {
      final probe = File(p.join(folderPath, '.timer_write_test'));
      probe.writeAsStringSync('');
      probe.deleteSync();
      return null;
    } on FileSystemException {
      return 'not writable';
    }
  }
}
