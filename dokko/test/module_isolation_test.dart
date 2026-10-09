// FASE 26 — Aislamiento entre módulos de negocio.
//
// Ningún módulo (gym, real_estate, salon) debe importar código de otro módulo.
// Solo pueden compartir código a través de lib/core (tema, API, widgets, etc.).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const modules = ['gym', 'real_estate', 'salon'];

  for (final module in modules) {
    test('módulo $module no importa otros módulos de negocio', () {
      final files = Directory('lib/modules/$module')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();
      expect(files, isNotEmpty,
          reason: 'El módulo $module debería tener archivos de código');

      final violations = <String>[];
      for (final file in files) {
        final content = file.readAsStringSync();
        for (final other in modules) {
          if (other == module) continue;
          if (content.contains("modules/$other/")) {
            violations.add('${file.path} -> importa "modules/$other/"');
          }
        }
      }

      expect(violations, isEmpty,
          reason: 'Aislamiento de módulo incumplido:\n${violations.join('\n')}');
    });
  }
}