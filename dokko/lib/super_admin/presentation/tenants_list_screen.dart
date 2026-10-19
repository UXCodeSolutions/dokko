import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import '../../../core/api/api_provider.dart';
import '../../../core/theme/dokko_tokens.dart';
import '../../../core/widgets/dokko_button.dart';
import '../../../core/widgets/dokko_empty_state.dart';

class TenantsListScreen extends ConsumerStatefulWidget {
  const TenantsListScreen({super.key});

  @override
  ConsumerState<TenantsListScreen> createState() => _TenantsListScreenState();
}

class _TenantsListScreenState extends ConsumerState<TenantsListScreen> {
  List<Map<String, dynamic>> _tenants = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchTenants();
  }

  Future<void> _fetchTenants() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final dynamic data = await api.get('/super-admin/tenants');
      if (!mounted) return;
      setState(() {
        _tenants = List<Map<String, dynamic>>.from(data as List);
        _isLoading = false;
      });
    } on HttpException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error del servidor: ${e.message}';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No se pudo conectar al servidor. Verifica que esté activo.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DokkoTokens.space24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Clientes',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: DokkoTokens.text,
                ),
              ),
              DokkoButton(
                label: 'Nuevo Cliente',
                onPressed: () => context.go('/super-admin/tenants/new'),
              ),
            ],
          ),
          const SizedBox(height: DokkoTokens.space24),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  size: 40, color: DokkoTokens.red),
                              const SizedBox(height: 16),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: DokkoTokens.text2, fontSize: 14),
                              ),
                              const SizedBox(height: 20),
                              DokkoButton(
                                label: 'Reintentar',
                                onPressed: _fetchTenants,
                              ),
                            ],
                          ),
                        ),
                      )
                    : _tenants.isEmpty
                        ? const DokkoEmptyState(
                            icon: Icons.business_rounded,
                            message: 'No hay clientes registrados.',
                          )
                        : GridView.builder(
                        padding: const EdgeInsets.only(bottom: DokkoTokens.space16),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 330,
                          mainAxisSpacing: DokkoTokens.space16,
                          crossAxisSpacing: DokkoTokens.space16,
                          childAspectRatio: 1.45,
                        ),
                        itemCount: _tenants.length,
                        itemBuilder: (context, index) {
                          final tenant = _tenants[index];
                          final id = tenant['id']?.toString() ?? '';
                          return TenantCard(
                            tenant: tenant,
                            onTap: () =>
                                context.go('/super-admin/tenants/$id'),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de tenant con la identidad de marca ({logo}, color primario) y los
/// datos esenciales. Al pulsar la tarjeta se abre el detalle del tenant.
class TenantCard extends StatefulWidget {
  final Map<String, dynamic> tenant;
  final VoidCallback onTap;

  const TenantCard({super.key, required this.tenant, required this.onTap});

  @override
  State<TenantCard> createState() => _TenantCardState();
}

class _TenantCardState extends State<TenantCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = _brandColorOf(widget.tenant);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: DokkoTokens.bg,
            borderRadius: BorderRadius.circular(DokkoTokens.radiusLg),
            border: Border.all(
              color: _hovered ? color.withValues(alpha: 0.5) : DokkoTokens.line,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.10),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(height: 3, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(DokkoTokens.space16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _TenantLogo(widget.tenant),
                          const SizedBox(width: DokkoTokens.space12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.tenant['name']?.toString() ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: DokkoTokens.text,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: DokkoTokens.space4),
                                _ModulePill(
                                  label: _moduleLabel(
                                      widget.tenant['module_slug']?.toString() ??
                                          ''),
                                  color: color,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: DokkoTokens.space8),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: _hovered ? color : DokkoTokens.text3,
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        height: 1,
                        color: DokkoTokens.line,
                      ),
                      const SizedBox(height: DokkoTokens.space12),
                      Row(
                        children: [
                          Expanded(
                            child: _MiniInfo(
                              label: 'Propietario',
                              value:
                                  widget.tenant['account_owners']?['email']
                                          ?.toString() ??
                                      'Sin asignar',
                            ),
                          ),
                          const SizedBox(width: DokkoTokens.space12),
                          Expanded(
                            child: _MiniInfo(
                              label: 'Creado',
                              value: _shortDate(
                                  widget.tenant['created_at']?.toString()),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  final String label;
  final String value;

  const _MiniInfo({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: DokkoTokens.text3,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: DokkoTokens.text2,
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ModulePill extends StatelessWidget {
  final String label;
  final Color color;

  const _ModulePill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DokkoTokens.space8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

String _moduleLabel(String slug) {
  switch (slug) {
    case 'gym':
      return 'Gimnasio';
    case 'salon':
      return 'Salón / Barbería';
    case 'real_estate':
      return 'Inmobiliaria';
    default:
      return slug;
  }
}

String _shortDate(String? raw) {
  if (raw == null) return '—';
  final date = DateTime.tryParse(raw);
  if (date == null) return '—';
  final months = [
    '', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];
  return '${date.day} ${months[date.month]} ${date.year}';
}

Color _brandColorOf(Map<String, dynamic> item) {
  final brand = item['brand_config'];
  if (brand is Map) {
    final raw = brand['primary_color'];
    if (raw is String) {
      final hex = raw.replaceFirst('#', '');
      if (hex.length == 6) {
        final parsed = int.tryParse(hex, radix: 16);
        if (parsed != null) return Color(0xFF000000 | parsed);
      }
    }
  }
  return DokkoTokens.accentDefault;
}

/// Logo del tenant: imagen desde storage si existe, si no las iniciales con el
/// color de marca. Se muestra como tarjeta redondeada.
class _TenantLogo extends StatelessWidget {
  final Map<String, dynamic> item;

  const _TenantLogo(this.item);

  String _initials() {
    final words = (item['name'] ?? '')
        .toString()
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    return words.isEmpty ? 'D' : words;
  }

  @override
  Widget build(BuildContext context) {
    final logo = item['logo_url'] as String?;
    final color = _brandColorOf(item);
    final initials = _initials();

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(DokkoTokens.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      clipBehavior: Clip.antiAlias,
      child: (logo == null || logo.isEmpty)
          ? _AvatarFallback(initials: initials, color: color)
          : Image.network(
              logo,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _AvatarFallback(initials: initials, color: color),
            ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final String initials;
  final Color color;

  const _AvatarFallback({required this.initials, required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}