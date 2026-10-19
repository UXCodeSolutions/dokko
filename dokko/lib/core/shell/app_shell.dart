import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/dokko_tokens.dart';
import '../theme/brand_theme.dart';
import '../modules/module_definition.dart';
import '../providers/tenant_provider.dart';
import '../auth/auth_provider.dart';
import '../../super_admin/widgets/support_mode_banner.dart';
import '../../super_admin/providers/super_admin_provider.dart';

class AppShell extends ConsumerWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final module = ref.watch(activeModuleProvider);
    final tenantAsync = ref.watch(tenantProvider);
    final adminState = ref.watch(superAdminAuthProvider);
    final inSupportMode = adminState.supportTenantId != null;

    final tenant = tenantAsync.value;

    // FASE 24 — Tenant suspendido/cancelado: bloqueo de acceso con mensaje claro.
    if (tenant != null && !tenant.isActive && !inSupportMode) {
      return SuspendedTenantScreen(tenant: tenant);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;
        final brand = ref.watch(brandColorsProvider);

        if (isMobile) {
          return Scaffold(
            backgroundColor: DokkoTokens.bg,
            appBar: AppBar(
              backgroundColor: DokkoTokens.surface,
              elevation: 0,
              centerTitle: false,
              titleSpacing: 0,
              title: Row(
                children: [
                  _BrandLogo(logoUrl: tenant?.logoUrl),
                  const SizedBox(width: DokkoTokens.space8),
                  Expanded(
                    child: Text(
                      tenant?.name ?? 'Dokko',
                      style: const TextStyle(
                        color: DokkoTokens.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (module != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DokkoTokens.space8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: brand.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        module.title,
                        style: TextStyle(
                          color: brand.onAccent.withValues(alpha: 0.85),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: DokkoTokens.space12),
                  ],
                ],
              ),
              leading: Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu_rounded, color: DokkoTokens.text),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
            ),
            drawer: Drawer(
              backgroundColor: DokkoTokens.surface,
              child: SafeArea(
                child: _DokkoSidebar(module: module, tenant: tenant, isDrawer: true),
              ),
            ),
            body: Column(
              children: [
                if (inSupportMode) const SupportModeBanner(),
                Expanded(child: SafeArea(child: child)),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: DokkoTokens.bg,
          body: Column(
            children: [
              if (inSupportMode) const SupportModeBanner(),
              Expanded(
                child: Row(
                  children: [
                    _DokkoSidebar(module: module, tenant: tenant),
                    Expanded(child: child),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Lock screen para negocios suspendidos/cancelados (FASE 24).
class SuspendedTenantScreen extends StatelessWidget {
  final TenantData tenant;
  const SuspendedTenantScreen({super.key, required this.tenant});

  @override
  Widget build(BuildContext context) {
    final isCancelled = tenant.status == 'cancelled';
    final brand = Theme.of(context).extension<BrandColors>() ?? BrandColors.fallback;
    return Scaffold(
      backgroundColor: DokkoTokens.bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            padding: const EdgeInsets.all(DokkoTokens.space32),
            decoration: BoxDecoration(
              color: DokkoTokens.surface,
              borderRadius: BorderRadius.circular(DokkoTokens.radiusLg),
              border: Border.all(color: DokkoTokens.line),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: (isCancelled ? DokkoTokens.amber : DokkoTokens.red)
                        .withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    isCancelled ? Icons.block_rounded : Icons.pause_circle_outline_rounded,
                    size: 30,
                    color: isCancelled ? DokkoTokens.amber : DokkoTokens.red,
                  ),
                ),
                const SizedBox(height: DokkoTokens.space16),
                const Text(
                  'Suscripción suspendida',
                  style: TextStyle(color: DokkoTokens.text, fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: DokkoTokens.space8),
                Text(
                  isCancelled
                      ? 'El negocio "${tenant.name}" fue cancelado.'
                      : 'El negocio "${tenant.name}" suspendió su suscripción por falta de pago.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: DokkoTokens.text2, fontSize: 13),
                ),
                const SizedBox(height: DokkoTokens.space12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: DokkoTokens.space12, vertical: DokkoTokens.space8),
                  decoration: BoxDecoration(
                    color: brand.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(DokkoTokens.radiusMd),
                  ),
                  child: Text(
                    'Para reactivar tu suscripción, renueva el pago o contacta a soporte en hola@dokko.do.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: brand.onAccent.withValues(alpha: 0.85), fontSize: 12),
                  ),
                ),
                const SizedBox(height: DokkoTokens.space20),
                _NavLogoutButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DokkoSidebar extends ConsumerWidget {
  final ModuleDefinition? module;
  final TenantData? tenant;
  final bool isDrawer;

  const _DokkoSidebar({this.module, this.tenant, this.isDrawer = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocation = GoRouterState.of(context).uri.toString();
    final brand = ref.watch(brandColorsProvider);

    return Container(
      width: isDrawer ? double.infinity : 220,
      decoration: BoxDecoration(
        color: DokkoTokens.surface,
        border: isDrawer
            ? null
            : const Border(right: BorderSide(color: DokkoTokens.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header del sidebar: logo de marca, nombre del tenant y módulo
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DokkoTokens.space16,
              vertical: DokkoTokens.space20,
            ),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: DokkoTokens.line)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _BrandLogo(logoUrl: tenant?.logoUrl),
                    const SizedBox(width: DokkoTokens.space8),
                    Expanded(
                      child: Text(
                        tenant?.name ?? 'Dokko',
                        style: const TextStyle(
                          color: DokkoTokens.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DokkoTokens.space8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DokkoTokens.space8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: brand.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 8, color: brand.accent),
                      const SizedBox(width: 6),
                      Text(
                        module?.title ?? 'Dokko',
                        style: TextStyle(
                          color: brand.onAccent.withValues(alpha: 0.85),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Items de navegación
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: DokkoTokens.space8),
              children: [
                ...?module?.navItems.map((item) {
                      final isActive = currentLocation.startsWith(item.path);
                      return _NavItem(item: item, isActive: isActive, accent: brand.accent);
                    }),
                const Divider(height: 16, color: DokkoTokens.line),
                _NavEntry(
                  icon: Icons.receipt_long_outlined,
                  label: 'Estado de cuenta',
                  isActive: currentLocation.startsWith('/billing'),
                  accent: brand.accent,
                  onTap: () => context.go('/billing'),
                ),
              ],
            ),
          ),
          // Footer con logout
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: DokkoTokens.line)),
            ),
            child: Column(
              children: [
                const _NavLogoutButton(),
                Padding(
                  padding: const EdgeInsets.only(bottom: DokkoTokens.space16),
                  child: Opacity(
                    opacity: 0.4,
                    child: Image.asset(
                      'assets/images/dokkologos/DokkoIsoClaro.png',
                      height: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandLogo extends StatelessWidget {
  final String? logoUrl;

  const _BrandLogo({this.logoUrl});

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).extension<BrandColors>() ?? BrandColors.fallback;
    if (logoUrl != null && logoUrl!.isNotEmpty) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: DokkoTokens.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          logoUrl!,
          width: 28,
          height: 28,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _brandOrbital(brand),
        ),
      );
    }
    return _brandOrbital(brand);
  }

  Widget _brandOrbital(BrandColors brand) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: brand.accent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.auto_awesome_rounded, size: 14, color: brand.onAccent),
    );
  }
}

class _NavItem extends StatefulWidget {
  final ModuleNavItem item;
  final bool isActive;
  final Color accent;

  const _NavItem({
    required this.item,
    required this.isActive,
    required this.accent,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).extension<BrandColors>() ?? BrandColors.fallback;
    final accent = widget.accent;
    final bg = widget.isActive
        ? accent.withValues(alpha: 0.14)
        : _hovered
            ? DokkoTokens.line
            : Colors.transparent;

    // En ítem activo usamos el onAccent legible (garantizado por contraste).
    final textColor = widget.isActive ? brand.onAccent.withValues(alpha: 0.92) : DokkoTokens.text2;
    final iconColor = widget.isActive ? accent : DokkoTokens.text3;
    final leftMarker = widget.isActive ? accent : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
            Navigator.of(context).pop();
          }
          context.go(widget.item.path);
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
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: leftMarker,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 8),
              Icon(widget.item.icon, size: 16, color: iconColor),
              const SizedBox(width: DokkoTokens.space12),
              Text(
                widget.item.label,
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

class _NavEntry extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color accent;
  final VoidCallback onTap;

  const _NavEntry({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_NavEntry> createState() => _NavEntryState();
}

class _NavEntryState extends State<_NavEntry> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).extension<BrandColors>() ?? BrandColors.fallback;
    final bg = widget.isActive
        ? widget.accent.withValues(alpha: 0.14)
        : _hovered
            ? DokkoTokens.line
            : Colors.transparent;
    final textColor = widget.isActive ? brand.onAccent.withValues(alpha: 0.92) : DokkoTokens.text2;
    final iconColor = widget.isActive ? widget.accent : DokkoTokens.text3;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
            Navigator.of(context).pop();
          }
          widget.onTap();
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
  const _NavLogoutButton();

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
            try {
              await ref.read(authProvider.notifier).signOut();
            } catch (e) {
              debugPrint('Error al cerrar sesión (temporal): $e');
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
