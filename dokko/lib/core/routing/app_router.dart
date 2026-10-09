import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/auth_provider.dart';
import '../auth/presentation/login_screen.dart';
import '../shell/app_shell.dart';
import '../providers/tenant_provider.dart';

import '../../super_admin/presentation/super_admin_login_screen.dart';
import '../../super_admin/shell/super_admin_shell.dart';
import '../../super_admin/presentation/tenants_list_screen.dart';
import '../../super_admin/presentation/create_tenant_screen.dart';
import '../../super_admin/presentation/account_owners_list_screen.dart';
import '../../super_admin/presentation/modules_catalog_screen.dart';
import '../../super_admin/presentation/tenant_billing_screen.dart';
import '../../super_admin/presentation/tenant_detail_screen.dart';
import '../../super_admin/presentation/audit_logs_screen.dart';

import '../modules/available_modules.dart';

import '../../modules/design_system/presentation/design_system_preview.dart';
import '../billing/presentation/billing_statement_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final tenantAsync = ref.watch(tenantProvider);

  // Colectamos todas las rutas de todos los módulos registrados
  final moduleRoutes = availableModules.values
      .expand((module) => module.routes)
      .toList();

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: _AuthRefreshNotifier(ref),
    redirect: (context, state) {
      final isAuth = authState.value?.session != null;
      final location = state.uri.toString();
      final isLoginRoute = location == '/login';

      // Mientras carga, no redirigir
      if (authState.isLoading) return null;

      // Sin sesión → login (excepto si va a super-admin/login)
      if (!isAuth && !isLoginRoute && location != '/super-admin/login') return '/login';

      // Con sesión en el login → redirigir al dashboard del módulo
      if (isAuth && isLoginRoute) {
        // Verificar si es super-admin
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null && user.appMetadata['is_super_admin'] == true) {
          return '/super-admin/tenants';
        }

        final tenant = tenantAsync.value;
        if (tenant != null) {
          final module = getModule(tenant.moduleSlug);
          return module?.dashboardPath ?? '/design-system';
        }
        // Si el tenant aún está cargando, esperar
        if (tenantAsync.isLoading) return null;
        // Fallback al design system para testing
        return '/design-system';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const LoginScreen(),
          transitionsBuilder: (context, animation, p, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        path: '/super-admin/login',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const SuperAdminLoginScreen(),
          transitionsBuilder: (context, animation, p, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => SuperAdminShell(child: child),
        routes: [
          GoRoute(
            path: '/super-admin/tenants',
            pageBuilder: (context, state) => CustomTransitionPage(
              child: const TenantsListScreen(),
              transitionsBuilder: (context, animation, p, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          ),
          GoRoute(
            path: '/super-admin/tenants/new',
            pageBuilder: (context, state) => CustomTransitionPage(
              child: const CreateTenantScreen(),
              transitionsBuilder: (context, animation, p, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          ),
          GoRoute(
            path: '/super-admin/owners',
            pageBuilder: (context, state) => CustomTransitionPage(
              child: const AccountOwnersListScreen(),
              transitionsBuilder: (context, animation, p, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          ),
          GoRoute(
            path: '/super-admin/modules',
            pageBuilder: (context, state) => CustomTransitionPage(
              child: const ModulesCatalogScreen(),
              transitionsBuilder: (context, animation, p, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          ),
          GoRoute(
            path: '/super-admin/billing',
            pageBuilder: (context, state) => CustomTransitionPage(
              child: const TenantBillingScreen(),
              transitionsBuilder: (context, animation, p, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          ),
          GoRoute(
            path: '/super-admin/tenants/:id',
            pageBuilder: (context, state) => CustomTransitionPage(
              child: TenantDetailScreen(tenantId: state.pathParameters['id']!),
              transitionsBuilder: (context, animation, p, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          ),
          GoRoute(
            path: '/super-admin/audit',
            pageBuilder: (context, state) => CustomTransitionPage(
              child: const AuditLogsScreen(),
              transitionsBuilder: (context, animation, p, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          ),
        ],
      ),
      // Ruta del design system (solo para desarrollo/testing)
      GoRoute(
        path: '/design-system',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const DesignSystemPreview(),
          transitionsBuilder: (context, animation, p, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      // App shell que envuelve todas las rutas de módulos
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/billing',
            pageBuilder: (context, state) => CustomTransitionPage(
              child: const BillingStatementScreen(),
              transitionsBuilder: (context, animation, p, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          ),
          ...moduleRoutes,
        ],
      ),
    ],
  );
});

/// Notifier que notifica al GoRouter cuando cambia el estado de auth o tenant
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen(authStateProvider, (p, n) {
      notifyListeners();
    });
    ref.listen(tenantProvider, (p, n) {
      notifyListeners();
    });
  }
}
