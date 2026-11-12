import 'package:flutter_test/flutter_test.dart';
import 'package:timer/feature/tracker/presentation/quick_start_picker.dart';

void main() {
  test('empty query returns all names unfiltered', () {
    expect(
      filterActivityNames(['Client X', 'Deep Work'], ''),
      ['Client X', 'Deep Work'],
    );
  });

  test('filters case-insensitively by substring', () {
    expect(
      filterActivityNames(['Client X', 'Deep Work'], 'cli'),
      ['Client X'],
    );
  });

  test('no match returns an empty list', () {
    expect(filterActivityNames(['Client X'], 'zzz'), isEmpty);
  });
}
