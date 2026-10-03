
import 'package:flutter_test/flutter_test.dart';
import 'narrative_src.dart';

void main() {
  test('narrativeSideSource 拼接叙事侧源码', () {
    final src = narrativeSideSource();
    expect(src, contains('mixin GameNarrativeMixin'));
    expect(src, contains('GameSummaryMemoryMixin'));
    final stripped = narrativeSideSource(stripComments: true);
    expect(stripped.length, lessThan(src.length));
  });
}
