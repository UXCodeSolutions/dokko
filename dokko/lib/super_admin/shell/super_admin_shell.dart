import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/dokko_tokens.dart';
import '../providers/super_admin_provider.dart';

class SuperAdminShell extends ConsumerWidget {
  final Widget child;

  const SuperAdminShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;

        if (isMobile) {
          return Scaffold(
            backgroundColor: DokkoTokens.bg,
            appBar: AppBar(
              backgroundColor: DokkoTokens.surface,
              elevation: 0,
              centerTitle: true,
              title: Image.asset(
                'assets/images/dokkologos/dokkoLogoClaro.png',
                height: 36,
                fit: BoxFit.contain,
              ),
              leading: Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu_rounded, color: DokkoTokens.text),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
            ),
            drawer: const Drawer(
              backgroundColor: DokkoTokens.surface,
              child: SafeArea(
                child: _SuperAdminSidebar(isDrawer: true),
              ),
            ),
            body: SafeArea(child: child),
          );
        }

        return Scaffold(
          backgroundColor: DokkoTokens.bg,
          body: Row(
            children: [
              const _SuperAdminSidebar(),
              Expanded(child: child),
            ],
          ),
        );
      },
    );
  }
}

class _SuperAdminSidebar extends ConsumerWidget {
  final bool isDrawer;

  const _SuperAdminSidebar({this.isDrawer = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocation = GoRouterState.of(context).uri.toString();

    return Container(
      width: isDrawer ? double.infinity : 240,
      decoration: BoxDecoration(
        color: DokkoTokens.surface,
        border: isDrawer
            ? null
            : const Border(right: BorderSide(color: DokkoTokens.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header — logotipo completo de Dokko
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DokkoTokens.space20,
              vertical: DokkoTokens.space20,
            ),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: DokkoTokens.line)),
            ),
            child: Image.asset(
              'assets/images/dokkologos/dokkoLogoClaro.png',
              height: 48,
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
            ),
          ),

          // Nav Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: DokkoTokens.space8),
              children: [
                _NavItem(
                  icon: Icons.business_rounded,
                  label: 'Clientes',
                  path: '/super-admin/tenants',
                  isActive: currentLocation.startsWith('/super-admin/tenants'),
                ),
                _NavItem(
                  icon: Icons.manage_accounts_rounded,
                  label: 'Propietarios',
                  path: '/super-admin/owners',
                  isActive: currentLocation.startsWith('/super-admin/owners'),
                ),
                _NavItem(
                  icon: Icons.view_module_rounded,
                  label: 'Módulos y Planes',
                  path: '/super-admin/modules',
                  isActive: currentLocation.startsWith('/super-admin/modules'),
                ),
                _NavItem(
                  icon: Icons.receipt_long_rounded,
                  label: 'Facturación Global',
                  path: '/super-admin/billing',
                  isActive: currentLocation.startsWith('/super-admin/billing'),
                ),
                _NavItem(
                  icon: Icons.history_rounded,
                  label: 'Auditoría',
                  path: '/super-admin/audit',
                  isActive: currentLocation.startsWith('/super-admin/audit'),
                ),
              ],
            ),
          ),
          // Footer Logout
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: DokkoTokens.line)),
            ),
            child: _NavLogoutButton(),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final String path;
  final bool isActive;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.path,
    required this.isActive,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.isActive
        ? DokkoTokens.lineStrong
        : _hovered
            ? DokkoTokens.line
            : Colors.transparent;

    final textColor = widget.isActive ? DokkoTokens.text : DokkoTokens.text2;
    final iconColor = widget.isActive ? DokkoTokens.text : DokkoTokens.text3;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
            Navigator.of(context).pop();
          }
          context.go(widget.path);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(
            horizontal: DokkoTokens.space8,
            vertical: 2,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: DokkoTokens.space12,
            vertical: DokkoTokens.space8,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(DokkoTokens.radiusMd),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 16, color: iconColor),
              const SizedBox(width: DokkoTokens.space12),
              Text(
                widget.label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavLogoutButton extends ConsumerStatefulWidget {
  @override
  ConsumerState<_NavLogoutButton> createState() => _NavLogoutButtonState();
}

class _NavLogoutButtonState extends ConsumerState<_NavLogoutButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () async {
          if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
            Navigator.of(context).pop();
          }
          await Supabase.instance.client.auth.signOut();
          ref.read(superAdminAuthProvider.notifier).reset();
          if (context.mounted) {
            context.go('/super-admin/login');
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.all(DokkoTokens.space8),
          padding: const EdgeInsets.symmetric(
            horizontal: DokkoTokens.space12,
            vertical: DokkoTokens.space8,
          ),
          decoration: BoxDecoration(
            color: _hovered ? DokkoTokens.line : Colors.transparent,
            borderRadius: BorderRadius.circular(DokkoTokens.radiusMd),
          ),
          child: const Row(
            children: [
              Icon(Icons.logout_rounded, size: 16, color: DokkoTokens.text3),
              SizedBox(width: DokkoTokens.space12),
              Text(
                'Cerrar sesión',
                style: TextStyle(color: DokkoTokens.text2, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
