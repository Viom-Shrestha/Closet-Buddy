import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('theme guardrails: no direct color literals in non-theme UI', () {
    final libDir = Directory('lib');
    final violations = <String>[];

    for (final file in _dartFiles(libDir)) {
      final normalizedPath = file.path.replaceAll('\\', '/');
      if (normalizedPath.startsWith('lib/theme/')) {
        continue;
      }

      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (RegExp(r'\bAppHexColors\.').hasMatch(line)) {
          violations.add('$normalizedPath:${i + 1} uses AppHexColors directly');
        }
        if (RegExp(r'\bColors\.').hasMatch(line)) {
          violations.add('$normalizedPath:${i + 1} uses Colors.* directly');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: violations.isEmpty ? null : violations.join('\n'),
    );
  });
}

Iterable<File> _dartFiles(Directory root) sync* {
  for (final entity in root.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      yield entity;
    }
  }
}
