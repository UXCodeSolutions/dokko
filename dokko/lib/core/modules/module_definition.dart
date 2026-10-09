import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Elemento de navegación que aparece en el sidebar del módulo
class ModuleNavItem {
  final IconData icon;
  final String label;
  final String path;

  const ModuleNavItem({
    required this.icon,
    required this.label,
    required this.path,
  });
}

/// Contrato que todo módulo de Dokko debe implementar.
/// Un módulo NO puede importar código de otro módulo.
/// Solo puede importar de `core/` y `core/widgets/`.
abstract class ModuleDefinition {
  /// Identificador único del módulo (coincide con tenants.module_slug)
  String get slug;

  /// Nombre visible en el sidebar y en la UI
  String get title;

  /// Ícono representativo del módulo
  IconData get icon;

  /// Ruta raíz a la que redirige tras el login
  String get dashboardPath;

  /// Items de navegación que se inyectan en el sidebar
  List<ModuleNavItem> get navItems;

  /// Rutas que este módulo aporta al GoRouter global.
  /// Todas las rutas deben estar dentro del prefijo del módulo.
  List<RouteBase> get routes;
}
