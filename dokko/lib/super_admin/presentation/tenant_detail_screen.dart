import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';

import '../../../core/theme/dokko_tokens.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../core/widgets/dokko_button.dart';
import '../../../core/widgets/dokko_card.dart';
import '../../../core/widgets/dokko_input.dart';
import '../providers/super_admin_provider.dart';

class TenantDetailScreen extends ConsumerStatefulWidget {
  final String tenantId;
  const TenantDetailScreen({super.key, required this.tenantId});

  @override
  ConsumerState<TenantDetailScreen> createState() => _TenantDetailScreenState();
}

class _TenantDetailScreenState extends ConsumerState<TenantDetailScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _tenant;
  bool _isLoading = true;
  bool _enteringSupport = false;
  bool _generatingBrand = false;
  bool _savingBrand = false;
  bool _updatingStatus = false;

  // Controladores de edición de marca
  final _primaryHexCtrl = TextEditingController();
  final _secondaryHexCtrl = TextEditingController();

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchTenant();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _primaryHexCtrl.dispose();
    _secondaryHexCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchTenant() async {
    setState(() => _isLoading = true);
    try {
      final token =
          Supabase.instance.client.auth.currentSession?.accessToken ?? '';
      final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000';
      final response = await http.get(
        Uri.parse('$baseUrl/super-admin/tenants/${widget.tenantId}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode != 200) {
        throw Exception('Error del servidor: ${response.body}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final brand = data['brand_config'] as Map<String, dynamic>? ?? {};

      setState(() {
        _tenant = data;
        _isLoading = false;
        _primaryHexCtrl.text =
            brand['primary_color']?.toString().toUpperCase() ?? '#3E63DD';
        _secondaryHexCtrl.text =
            brand['secondary_color']?.toString().toUpperCase() ?? '#111113';
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar cliente: $e')),
        );
      }
    }
  }

  Future<void> _enterSupportMode() async {
    if (_tenant == null) return;
    setState(() => _enteringSupport = true);
    await ref
        .read(superAdminAuthProvider.notifier)
        .enterSupportMode(widget.tenantId, _tenant!['name']);

    if (mounted) {
      final slug = _tenant!['module_slug'] as String? ?? 'gym';
      context.go('/$slug/dashboard');
    }
  }

  Future<void> _changeStatus(String newStatus) async {
    if (_tenant == null) return;
    setState(() => _updatingStatus = true);
    try {
      final token =
          Supabase.instance.client.auth.currentSession?.accessToken ?? '';
      final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000';
      final response = await http.patch(
        Uri.parse('$baseUrl/super-admin/tenants/${widget.tenantId}/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'status': newStatus}),
      );

      if (response.statusCode != 200) {
        throw Exception('Error: ${response.body}');
      }

      final updated = jsonDecode(response.body) as Map<String, dynamic>;
      setState(() {
        _tenant!['status'] = updated['status'];
        _updatingStatus = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: DokkoTokens.surface,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: DokkoTokens.green, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Estado actualizado a ${newStatus.toUpperCase()}',
                  style: const TextStyle(color: DokkoTokens.text),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _updatingStatus = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cambiar estado: $e')),
        );
      }
    }
  }

  Future<void> _showRenameDialog() async {
    if (_tenant == null) return;
    final nameCtrl = TextEditingController(text: _tenant!['name']);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DokkoTokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DokkoTokens.radiusLg),
          side: const BorderSide(color: DokkoTokens.line),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
        title: const Text(
          'Renombrar Cliente',
          style: TextStyle(
            color: DokkoTokens.text,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: SizedBox(
          width: 360,
          child: DokkoInput(
            label: 'Nombre comercial',
            controller: nameCtrl,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: DokkoTokens.text2)),
          ),
          DokkoButton(
            label: 'Guardar',
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed == true && nameCtrl.text.trim().isNotEmpty) {
      final newName = nameCtrl.text.trim();
      try {
        final token =
            Supabase.instance.client.auth.currentSession?.accessToken ?? '';
        final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000';
        await http.patch(
          Uri.parse('$baseUrl/super-admin/tenants/${widget.tenantId}'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'name': newName}),
        );
        setState(() {
          _tenant!['name'] = newName;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nombre actualizado exitosamente')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al renombrar: $e')),
          );
        }
      }
    }
  }

  Future<void> _generateColorsFromLogo() async {
    final files = await FilePicker.pickFiles(type: FileType.image);
    if (files.isEmpty) return;
    final file = files.first;
    final bytes = await file.readAsBytes();

    setState(() => _generatingBrand = true);
    try {
      final token =
          Supabase.instance.client.auth.currentSession?.accessToken ?? '';
      final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000';
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/super-admin/brand/extract'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: file.name,
      ));
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode != 200) {
        throw Exception('Error: ${response.body}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      setState(() {
        _primaryHexCtrl.text =
            data['primary_color']?.toString().toUpperCase() ?? _primaryHexCtrl.text;
        _secondaryHexCtrl.text =
            data['secondary_color']?.toString().toUpperCase() ?? _secondaryHexCtrl.text;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo extraer colores: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingBrand = false);
    }
  }

  Future<void> _saveBrand() async {
    final primary = _primaryHexCtrl.text.trim();
    final secondary = _secondaryHexCtrl.text.trim();

    setState(() => _savingBrand = true);
    try {
      final token =
          Supabase.instance.client.auth.currentSession?.accessToken ?? '';
      final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000';
      final response = await http.patch(
        Uri.parse('$baseUrl/super-admin/tenants/${widget.tenantId}/brand'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'primary_color': primary,
          'secondary_color': secondary,
        }),
      );
      if (response.statusCode != 200) {
        throw Exception('Error del servidor: ${response.body}');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Identidad de marca guardada con éxito. Los cambios ya son visibles.'),
          ),
        );
      }
      await _fetchTenant();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar la marca: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingBrand = false);
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        backgroundColor: DokkoTokens.surface,
        content: Text('$label copiado al portapapeles',
            style: const TextStyle(color: DokkoTokens.text)),
      ),
    );
  }

  Color _parseHex(String? raw, {Color fallback = DokkoTokens.accentDefault}) {
    if (raw == null || raw.isEmpty) return fallback;
    final cleaned = raw.replaceAll('#', '');
    if (cleaned.length == 6) {
      final val = int.tryParse('FF$cleaned', radix: 16);
      if (val != null) return Color(val);
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: DokkoTokens.bg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_tenant == null) {
      return Scaffold(
        backgroundColor: DokkoTokens.bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.business_center_outlined,
                  size: 48, color: DokkoTokens.text3),
              const SizedBox(height: 16),
              const Text('Cliente no encontrado',
                  style: TextStyle(color: DokkoTokens.text, fontSize: 18)),
              const SizedBox(height: 16),
              DokkoButton(
                label: 'Volver a Clientes',
                onPressed: () => context.go('/super-admin/tenants'),
              ),
            ],
          ),
        ),
      );
    }

    final brand = _tenant!['brand_config'] as Map<String, dynamic>? ?? {};
    final primaryColor = _parseHex(brand['primary_color']);
    final status = _tenant!['status'] as String? ?? 'active';
    final moduleSlug = _tenant!['module_slug'] as String? ?? 'gym';
    final ownerEmail =
        _tenant!['account_owners']?['email']?.toString() ?? 'Sin asignar';
    final users = List<Map<String, dynamic>>.from(_tenant!['tenant_users'] ?? []);

    return Scaffold(
      backgroundColor: DokkoTokens.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(DokkoTokens.space24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra de navegación superior (Breadcrumbs & Acciones)
              _buildTopBar(),
              const SizedBox(height: DokkoTokens.space20),

              // Hero Card interactiva con identidad de marca
              _buildHeroHeader(primaryColor, status, moduleSlug, ownerEmail),
              const SizedBox(height: DokkoTokens.space24),

              // TabBar de secciones
              Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: DokkoTokens.line)),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: DokkoTokens.text,
                  unselectedLabelColor: DokkoTokens.text3,
                  indicatorColor: primaryColor,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                  tabs: [
                    const Tab(
                      icon: Icon(Icons.dashboard_outlined, size: 18),
                      text: 'Resumen & Operaciones',
                    ),
                    const Tab(
                      icon: Icon(Icons.palette_outlined, size: 18),
                      text: 'Identidad & Live Preview',
                    ),
                    Tab(
                      icon: const Icon(Icons.people_outline_rounded, size: 18),
                      text: 'Usuarios (${users.length})',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DokkoTokens.space24),

              // Contenido de las pestañas
              AnimatedBuilder(
                animation: _tabController,
                builder: (context, _) {
                  switch (_tabController.index) {
                    case 0:
                      return _buildOverviewTab(
                          primaryColor, status, moduleSlug, ownerEmail, users);
                    case 1:
                      return _buildBrandTab(primaryColor);
                    case 2:
                      return _buildUsersTab(users);
                    default:
                      return const SizedBox();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 1. Barra Superior con Breadcrumb y Botones Rápidos
  // ─────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: DokkoTokens.space12,
      runSpacing: DokkoTokens.space12,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(DokkoTokens.radiusSm),
              onTap: () => context.go('/super-admin/tenants'),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.arrow_back_rounded,
                        size: 16, color: DokkoTokens.text2),
                    SizedBox(width: 6),
                    Text('Clientes',
                        style: TextStyle(
                            color: DokkoTokens.text2,
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
            const Text('  /  ',
                style: TextStyle(color: DokkoTokens.text3, fontSize: 14)),
            Text(
              _tenant!['name'] ?? '',
              style: const TextStyle(
                color: DokkoTokens.text,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Actualizar datos',
              icon: const Icon(Icons.refresh_rounded,
                  color: DokkoTokens.text2, size: 20),
              onPressed: _fetchTenant,
            ),
            const SizedBox(width: DokkoTokens.space8),
            DokkoButton(
              label: 'Entrar en modo soporte',
              isLoading: _enteringSupport,
              onPressed: _enterSupportMode,
            ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 2. Hero Header Card con Identidad Visual
  // ─────────────────────────────────────────────────────────────
  Widget _buildHeroHeader(
      Color primaryColor, String status, String moduleSlug, String ownerEmail) {
    final logoUrl = _tenant!['brand_config']?['logo_url'] as String?;

    return DokkoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo o Avatar de Marca
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(DokkoTokens.radiusLg),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                ),
                clipBehavior: Clip.antiAlias,
                child: (logoUrl != null && logoUrl.isNotEmpty)
                    ? Image.network(
                        logoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => Center(
                          child: Text(
                            (_tenant!['name'] ?? 'D').toString().substring(0, 1).toUpperCase(),
                            style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: primaryColor),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          (_tenant!['name'] ?? 'D').toString().substring(0, 1).toUpperCase(),
                          style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: primaryColor),
                        ),
                      ),
              ),
              const SizedBox(width: DokkoTokens.space20),

              // Nombre, Módulo e ID
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _tenant!['name'] ?? '',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: DokkoTokens.text,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Editar nombre',
                          icon: const Icon(Icons.edit_outlined,
                              size: 16, color: DokkoTokens.text3),
                          onPressed: _showRenameDialog,
                        ),
                      ],
                    ),
                    const SizedBox(height: DokkoTokens.space8),
                    Wrap(
                      spacing: DokkoTokens.space8,
                      runSpacing: DokkoTokens.space8,
                      children: [
                        _buildModuleBadge(moduleSlug, primaryColor),
                        _buildStatusMenu(status),
                        InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () =>
                              _copyToClipboard(_tenant!['id'], 'ID del cliente'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: DokkoTokens.line,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.fingerprint_rounded,
                                    size: 13, color: DokkoTokens.text3),
                                const SizedBox(width: 4),
                                Text(
                                  'ID: ${widget.tenantId.substring(0, 8)}…',
                                  style: const TextStyle(
                                      color: DokkoTokens.text2, fontSize: 11),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.copy_rounded,
                                    size: 11, color: DokkoTokens.text3),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 3. Pestaña 1: Resumen & Operaciones
  // ─────────────────────────────────────────────────────────────
  Widget _buildOverviewTab(Color primaryColor, String status, String moduleSlug,
      String ownerEmail, List<Map<String, dynamic>> users) {
    final createdAt = _tenant!['created_at']?.toString() ?? '';
    final retentionDays = _tenant!['retention_days'] ?? 90;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cuadrícula de 4 Métricas Clave
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 650;
            return GridView.count(
              crossAxisCount: isNarrow ? 2 : 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: DokkoTokens.space12,
              mainAxisSpacing: DokkoTokens.space12,
              childAspectRatio: isNarrow ? 1.5 : 1.7,
              children: [
                _buildMetricCard(
                  title: 'Módulo Operativo',
                  value: _moduleName(moduleSlug),
                  icon: _moduleIcon(moduleSlug),
                  color: primaryColor,
                ),
                _buildMetricCard(
                  title: 'Estado del Servicio',
                  value: status.toUpperCase(),
                  icon: status == 'active'
                      ? Icons.check_circle_rounded
                      : Icons.pause_circle_rounded,
                  color: status == 'active'
                      ? DokkoTokens.green
                      : DokkoTokens.amber,
                ),
                _buildMetricCard(
                  title: 'Usuarios Registrados',
                  value: users.length.toString(),
                  icon: Icons.group_rounded,
                  color: DokkoTokens.accentDefault,
                ),
                _buildMetricCard(
                  title: 'Días de Retención',
                  value: '$retentionDays días',
                  icon: Icons.history_rounded,
                  color: DokkoTokens.text2,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: DokkoTokens.space24),

        // Tarjeta de Propietario & Configuración
        DokkoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Información de Cuenta & Propietario',
                  style: TextStyle(
                      color: DokkoTokens.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: DokkoTokens.space16),
              _buildDetailRow(
                icon: Icons.person_outline_rounded,
                label: 'Propietario',
                value: ownerEmail,
                trailing: IconButton(
                  tooltip: 'Copiar correo',
                  icon: const Icon(Icons.copy_rounded,
                      size: 15, color: DokkoTokens.text3),
                  onPressed: () => _copyToClipboard(ownerEmail, 'Correo'),
                ),
              ),
              const Divider(color: DokkoTokens.line, height: 24),
              _buildDetailRow(
                icon: Icons.calendar_today_outlined,
                label: 'Fecha de Creación',
                value: _formatDate(createdAt),
              ),
              const Divider(color: DokkoTokens.line, height: 24),
              _buildDetailRow(
                icon: Icons.tag_rounded,
                label: 'ID Completo',
                value: widget.tenantId,
                trailing: IconButton(
                  tooltip: 'Copiar ID completo',
                  icon: const Icon(Icons.copy_rounded,
                      size: 15, color: DokkoTokens.text3),
                  onPressed: () =>
                      _copyToClipboard(widget.tenantId, 'ID del cliente'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: DokkoTokens.space24),

        // Gestión de Estado / Zona de Control
        DokkoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.shield_outlined,
                      color: DokkoTokens.amber, size: 20),
                  SizedBox(width: 8),
                  Text('Control de Suscripción & Acceso',
                      style: TextStyle(
                          color: DokkoTokens.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: DokkoTokens.space8),
              const Text(
                'Puedes pausar temporalmente el acceso del negocio ante pagos pendientes o reactivarlo inmediatamente.',
                style: TextStyle(color: DokkoTokens.text2, fontSize: 13),
              ),
              const SizedBox(height: DokkoTokens.space16),
              Wrap(
                spacing: DokkoTokens.space12,
                runSpacing: DokkoTokens.space12,
                children: [
                  if (status == 'active') ...[
                    DokkoButton(
                      label: 'Suspender Servicio',
                      variant: DokkoButtonVariant.outline,
                      isLoading: _updatingStatus,
                      onPressed: () => _changeStatus('suspended'),
                    ),
                    DokkoButton(
                      label: 'Cancelar Cliente',
                      variant: DokkoButtonVariant.ghost,
                      isLoading: _updatingStatus,
                      onPressed: () => _changeStatus('cancelled'),
                    ),
                  ] else ...[
                    DokkoButton(
                      label: 'Reactivar Servicio',
                      variant: DokkoButtonVariant.primary,
                      isLoading: _updatingStatus,
                      onPressed: () => _changeStatus('active'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 4. Pestaña 2: Identidad & Live Preview Interactivo
  // ─────────────────────────────────────────────────────────────
  Widget _buildBrandTab(Color primaryColor) {
    final previewPrimary = _parseHex(_primaryHexCtrl.text);
    final previewSecondary = _parseHex(_secondaryHexCtrl.text);
    final ratio = contrastRatio(previewPrimary, pickTextColor(previewPrimary));
    final level = ratio >= 7.0 ? 'AAA' : (ratio >= 4.5 ? 'AA' : 'FALLA');
    final isValid = ratio >= 4.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Live Preview Mockup
        DokkoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Vista Previa en Vivo (Live Component Preview)',
                      style: TextStyle(
                          color: DokkoTokens.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isValid
                          ? DokkoTokens.green.withValues(alpha: 0.15)
                          : DokkoTokens.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Contraste $level (${ratio.toStringAsFixed(1)}:1)',
                      style: TextStyle(
                        color: isValid ? DokkoTokens.green : DokkoTokens.red,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DokkoTokens.space12),
              const Text(
                'Así es como los miembros y el personal del cliente verán los componentes con su paleta de color:',
                style: TextStyle(color: DokkoTokens.text2, fontSize: 13),
              ),
              const SizedBox(height: DokkoTokens.space20),

              // Mockup interactivo
              Container(
                padding: const EdgeInsets.all(DokkoTokens.space20),
                decoration: BoxDecoration(
                  color: previewSecondary,
                  borderRadius: BorderRadius.circular(DokkoTokens.radiusLg),
                  border: Border.all(color: previewPrimary.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: previewPrimary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.store_rounded,
                              size: 18, color: pickTextColor(previewPrimary)),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _tenant!['name'] ?? 'Mi Negocio',
                          style: TextStyle(
                            color: pickTextColor(previewSecondary),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: previewPrimary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Activo',
                            style: TextStyle(
                              color: previewPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DokkoTokens.space20),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: previewPrimary,
                            foregroundColor: pickTextColor(previewPrimary),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(DokkoTokens.radiusMd),
                            ),
                          ),
                          child: const Text('Botón Principal'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            foregroundColor: previewPrimary,
                            side: BorderSide(color: previewPrimary),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(DokkoTokens.radiusMd),
                            ),
                          ),
                          child: const Text('Botón Secundario'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: DokkoTokens.space24),

        // Editor de colores & Extracción inteligente
        DokkoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ajustes de Paleta de Marca',
                  style: TextStyle(
                      color: DokkoTokens.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: DokkoTokens.space16),
              Wrap(
                spacing: DokkoTokens.space16,
                runSpacing: DokkoTokens.space16,
                children: [
                  SizedBox(
                    width: 220,
                    child: DokkoInput(
                      label: 'Color Primario (HEX)',
                      controller: _primaryHexCtrl,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: DokkoInput(
                      label: 'Color Secundario (HEX)',
                      controller: _secondaryHexCtrl,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DokkoTokens.space20),
              Wrap(
                spacing: DokkoTokens.space12,
                runSpacing: DokkoTokens.space12,
                children: [
                  DokkoButton(
                    label: 'Subir Logo para Extraer Paleta',
                    variant: DokkoButtonVariant.secondary,
                    isLoading: _generatingBrand,
                    onPressed: _generateColorsFromLogo,
                  ),
                  DokkoButton(
                    label: 'Guardar Paleta de Marca',
                    isLoading: _savingBrand,
                    onPressed: _saveBrand,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 5. Pestaña 3: Usuarios & Accesos
  // ─────────────────────────────────────────────────────────────
  Widget _buildUsersTab(List<Map<String, dynamic>> users) {
    if (users.isEmpty) {
      return DokkoCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: DokkoTokens.space32),
          child: Column(
            children: [
              const Icon(Icons.people_alt_outlined,
                  size: 48, color: DokkoTokens.text3),
              const SizedBox(height: 16),
              const Text('Sin usuarios adicionales vinculados',
                  style: TextStyle(
                      color: DokkoTokens.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text(
                'El propietario puede acceder directamente con su cuenta de super-admin o credenciales de tenant.',
                textAlign: TextAlign.center,
                style: TextStyle(color: DokkoTokens.text2, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return DokkoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Usuarios con Acceso al Panel',
              style: TextStyle(
                  color: DokkoTokens.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: DokkoTokens.space16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: users.length,
            separatorBuilder: (ctx, idx) =>
                const Divider(color: DokkoTokens.line, height: 16),
            itemBuilder: (context, index) {
              final user = users[index];
              final role = user['role']?.toString().toUpperCase() ?? 'STAFF';
              final userId = user['user_id']?.toString() ?? '';

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: DokkoTokens.line,
                  child: const Icon(Icons.person, color: DokkoTokens.text2),
                ),
                title: Text(
                  'Usuario: ${userId.substring(0, 12)}…',
                  style: const TextStyle(
                      color: DokkoTokens.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
                subtitle: Text('Rol: $role',
                    style: const TextStyle(
                        color: DokkoTokens.text2, fontSize: 12)),
                trailing: IconButton(
                  icon: const Icon(Icons.copy_rounded,
                      size: 16, color: DokkoTokens.text3),
                  onPressed: () =>
                      _copyToClipboard(userId, 'ID de usuario'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Helper Widgets
  // ─────────────────────────────────────────────────────────────
  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return DokkoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: DokkoTokens.text3, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
                color: DokkoTokens.text,
                fontSize: 17,
                fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: DokkoTokens.text3),
        const SizedBox(width: 12),
        SizedBox(
          width: 140,
          child: Text(label,
              style: const TextStyle(color: DokkoTokens.text2, fontSize: 13)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
                color: DokkoTokens.text,
                fontSize: 13,
                fontWeight: FontWeight.w500),
          ),
        ),
        ?trailing,
      ],
    );
  }

  Widget _buildModuleBadge(String slug, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_moduleIcon(slug), size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            _moduleName(slug),
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusMenu(String status) {
    final isAct = status == 'active';
    final isSusp = status == 'suspended';
    final color = isAct
        ? DokkoTokens.green
        : isSusp
            ? DokkoTokens.amber
            : DokkoTokens.red;

    return PopupMenuButton<String>(
      tooltip: 'Cambiar estado del cliente',
      color: DokkoTokens.surface,
      onSelected: _changeStatus,
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'active',
          child: Row(
            children: [
              Icon(Icons.check_circle_rounded,
                  color: DokkoTokens.green, size: 16),
              SizedBox(width: 8),
              Text('Activo', style: TextStyle(color: DokkoTokens.text)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'suspended',
          child: Row(
            children: [
              Icon(Icons.pause_circle_rounded,
                  color: DokkoTokens.amber, size: 16),
              SizedBox(width: 8),
              Text('Suspendido', style: TextStyle(color: DokkoTokens.text)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'cancelled',
          child: Row(
            children: [
              Icon(Icons.cancel_rounded, color: DokkoTokens.red, size: 16),
              SizedBox(width: 8),
              Text('Cancelado', style: TextStyle(color: DokkoTokens.text)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              status.toUpperCase(),
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down_rounded, size: 16, color: color),
          ],
        ),
      ),
    );
  }

  IconData _moduleIcon(String slug) {
    switch (slug) {
      case 'gym':
        return Icons.fitness_center_rounded;
      case 'salon':
        return Icons.content_cut_rounded;
      case 'real_estate':
        return Icons.apartment_rounded;
      default:
        return Icons.business_rounded;
    }
  }

  String _moduleName(String slug) {
    switch (slug) {
      case 'gym':
        return 'Gimnasio';
      case 'salon':
        return 'Salón & Belleza';
      case 'real_estate':
        return 'Inmobiliaria';
      default:
        return slug;
    }
  }

  String _formatDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final months = [
      '', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
    ];
    return '${parsed.day} ${months[parsed.month]} ${parsed.year}';
  }
}
