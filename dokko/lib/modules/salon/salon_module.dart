import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/modules/module_definition.dart';
import '../../core/theme/dokko_tokens.dart';
import '../../core/widgets/dokko_empty_state.dart';
import 'presentation/salon_dashboard_screen.dart';
import 'presentation/salon_agenda_screen.dart';
import 'presentation/salon_clients_screen.dart';
import 'presentation/salon_pos_screen.dart';
import 'presentation/salon_commissions_screen.dart';
import 'presentation/salon_reports_screen.dart';
import 'presentation/salon_messages_screen.dart';

class SalonModule implements ModuleDefinition {
  @override
  String get slug => 'salon';

  @override
  String get title => 'SalonOS';

  @override
  IconData get icon => Icons.content_cut_rounded;

  @override
  String get dashboardPath => '/salon/dashboard';

  @override
  List<ModuleNavItem> get navItems => const [
        ModuleNavItem(icon: Icons.dashboard_rounded, label: 'Dashboard', path: '/salon/dashboard'),
        ModuleNavItem(icon: Icons.calendar_today_rounded, label: 'Agenda', path: '/salon/agenda'),
        ModuleNavItem(icon: Icons.people_rounded, label: 'Clientes', path: '/salon/clients'),
        ModuleNavItem(icon: Icons.storefront_rounded, label: 'POS / Ventas', path: '/salon/pos'),
        ModuleNavItem(icon: Icons.monetization_on_rounded, label: 'Comisiones', path: '/salon/commissions'),
        ModuleNavItem(icon: Icons.chat_bubble_rounded, label: 'Mensajería', path: '/salon/messages'),
        ModuleNavItem(icon: Icons.bar_chart_rounded, label: 'Reportes', path: '/salon/reports'),
        ModuleNavItem(icon: Icons.settings_rounded, label: 'Configuración', path: '/salon/settings'),
      ];

  @override
  List<RouteBase> get routes => [
        GoRoute(
          path: '/salon/dashboard',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: const SalonDashboardScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: '/salon/agenda',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: const SalonAgendaScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: '/salon/clients',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: const SalonClientsScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: '/salon/pos',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: const SalonPosScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: '/salon/commissions',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: const SalonCommissionsScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: '/salon/reports',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: const SalonReportsScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: '/salon/messages',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: const SalonMessagesScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: '/salon/settings',
          pageBuilder: (context, state) => _placeholder(context, 'Configuración (Fase 22)'),
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
