import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/modules/module_definition.dart';

import 'presentation/gym_dashboard_screen.dart';
import 'presentation/gym_members_screen.dart';
import 'presentation/gym_member_detail_screen.dart';
import 'presentation/gym_member_form_screen.dart';
import 'presentation/gym_checkin_screen.dart';
import 'presentation/gym_memberships_screen.dart';
import 'presentation/gym_pos_screen.dart';
import 'presentation/gym_reports_screen.dart';
import 'presentation/gym_churn_screen.dart';
import 'presentation/gym_settings_screen.dart';

class GymModule implements ModuleDefinition {
  @override
  String get slug => 'gym';

  @override
  String get title => 'GymOS';

  @override
  IconData get icon => Icons.fitness_center_rounded;

  @override
  String get dashboardPath => '/gym/dashboard';

  @override
  List<ModuleNavItem> get navItems => const [
        ModuleNavItem(icon: Icons.dashboard_rounded, label: 'Dashboard', path: '/gym/dashboard'),
        ModuleNavItem(icon: Icons.group_rounded, label: 'Miembros', path: '/gym/members'),
        ModuleNavItem(icon: Icons.qr_code_scanner_rounded, label: 'Check-in', path: '/gym/checkin'),
        ModuleNavItem(icon: Icons.credit_card_rounded, label: 'Membresías', path: '/gym/memberships'),
        ModuleNavItem(icon: Icons.storefront_rounded, label: 'POS / Productos', path: '/gym/pos'),
        ModuleNavItem(icon: Icons.bar_chart_rounded, label: 'Reportes', path: '/gym/reports'),
        ModuleNavItem(icon: Icons.trending_down_rounded, label: 'Churn', path: '/gym/churn'),
        ModuleNavItem(icon: Icons.settings_rounded, label: 'Configuración', path: '/gym/settings'),
      ];

  @override
  List<RouteBase> get routes => [
        GoRoute(
          path: '/gym/dashboard',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: const GymDashboardScreen(),
            transitionsBuilder: (context, animation, p, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: '/gym/members',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: const GymMembersScreen(),
            transitionsBuilder: (context, animation, p, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: '/gym/members/new',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: const GymMemberFormScreen(),
            transitionsBuilder: (context, animation, p, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: '/gym/members/:id',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: GymMemberDetailScreen(
              memberId: state.pathParameters['id']!,
            ),
            transitionsBuilder: (context, animation, p, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: '/gym/members/:id/edit',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: GymMemberFormScreen(
              member: state.extra as Map<String, dynamic>?,
            ),
            transitionsBuilder: (context, animation, p, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: '/gym/checkin',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: const GymCheckinScreen(),
            transitionsBuilder: (context, animation, p, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: '/gym/memberships',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: const GymMembershipsScreen(),
            transitionsBuilder: (context, animation, p, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: '/gym/pos',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: const GymPosScreen(),
            transitionsBuilder: (context, animation, p, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: '/gym/reports',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: const GymReportsScreen(),
            transitionsBuilder: (context, animation, p, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: '/gym/churn',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: const GymChurnScreen(),
            transitionsBuilder: (context, animation, p, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: '/gym/settings',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: const GymSettingsScreen(),
            transitionsBuilder: (context, animation, p, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        ),
      ];
}
