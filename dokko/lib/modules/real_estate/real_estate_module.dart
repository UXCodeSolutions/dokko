import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/modules/module_definition.dart';
import '../../core/theme/dokko_tokens.dart';
import '../../core/widgets/dokko_empty_state.dart';

import 'presentation/dashboard_screen.dart';
import 'presentation/properties_screen.dart';
import 'presentation/property_form_screen.dart';
import 'presentation/leads_screen.dart';
import 'presentation/dossiers_screen.dart';
import 'presentation/commissions_screen.dart';
import 'presentation/reports_screen.dart';

class RealEstateModule implements ModuleDefinition {
  @override
  String get slug => 'real_estate';

  @override
  String get title => 'PropOS';

  @override
  IconData get icon => Icons.home_work_rounded;

  @override
  String get dashboardPath => '/real_estate/dashboard';

  @override
  List<ModuleNavItem> get navItems => const [
        ModuleNavItem(icon: Icons.dashboard_rounded, label: 'Dashboard', path: '/real_estate/dashboard'),
        ModuleNavItem(icon: Icons.home_rounded, label: 'Propiedades', path: '/real_estate/properties'),
        ModuleNavItem(icon: Icons.people_alt_rounded, label: 'Leads', path: '/real_estate/leads'),
        ModuleNavItem(icon: Icons.description_rounded, label: 'Dossiers', path: '/real_estate/dossiers'),
        ModuleNavItem(icon: Icons.monetization_on_rounded, label: 'Comisiones', path: '/real_estate/commissions'),
        ModuleNavItem(icon: Icons.bar_chart_rounded, label: 'Reportes', path: '/real_estate/reports'),
        ModuleNavItem(icon: Icons.settings_rounded, label: 'Configuración', path: '/real_estate/settings'),
      ];

  @override
  List<RouteBase> get routes => [
        GoRoute(
          path: '/real_estate/dashboard',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: const DashboardScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: '/real_estate/properties',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: const PropertiesScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: '/real_estate/properties/new',
          pageBuilder: (context, state) => const MaterialPage(
            child: PropertyWizardScreen(),
            fullscreenDialog: true,
          ),
        ),
        GoRoute(
          path: '/real_estate/leads',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: const LeadsScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: '/real_estate/dossiers',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: const DossiersScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: '/real_estate/commissions',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: const CommissionsScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: '/real_estate/reports',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: const ReportsScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: '/real_estate/settings',
          pageBuilder: (context, state) => _placeholder(context, 'Configuración (Fase 20)'),
        ),
      ];

  CustomTransitionPage _placeholder(BuildContext context, String name) {
    return CustomTransitionPage(
      child: Scaffold(
        backgroundColor: DokkoTokens.bg,
        body: DokkoEmptyState(
          icon: Icons.construction_rounded,
          message: '$name\nEsta pantalla se construirá en su fase correspondiente.',
        ),
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }
}
