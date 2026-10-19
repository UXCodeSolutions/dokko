import 'package:flutter/material.dart';
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
import '../providers/super_admin_provider.dart';

class TenantDetailScreen extends ConsumerStatefulWidget {
  final String tenantId;
  const TenantDetailScreen({super.key, required this.tenantId});

  @override
  ConsumerState<TenantDetailScreen> createState() => _TenantDetailScreenState();
}

class _TenantDetailScreenState extends ConsumerState<TenantDetailScreen> {
  Map<String, dynamic>? _tenant;
  bool _isLoading = true;
  bool _enteringSupport = false;
  bool _generatingBrand = false;
  bool _savingBrand = false;
  Map<String, dynamic>? _brandPreview;

  @override
  void initState() {
    super.initState();
    _fetchTenant();
  }

  Future<void> _fetchTenant() async {
    setState(() => _isLoading = true);
    try {
      // Vía backend (service role) para que el super-admin pueda ver CUALQUIER tenant,
      // no solo los que él creó como owner.
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
      setState(() {
        _tenant = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _enterSupportMode() async {
    if (_tenant == null) return;
    setState(() => _enteringSupport = true);
    await ref
        .read(superAdminAuthProvider.notifier)
        .enterSupportMode(widget.tenantId, _tenant!['name']);

    if (mounted) {
      // Obtener el módulo del tenant y navegar a su dashboard
      final slug = _tenant!['module_slug'] as String? ?? 'gym';
      context.go('/$slug/dashboard');
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
      setState(() => _brandPreview = data);
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
    if (_brandPreview == null) return;
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
          'primary_color': _brandPreview!['primary_color'],
          'secondary_color': _brandPreview!['secondary_color'],
        }),
      );
      if (response.statusCode != 200) {
        throw Exception('Error del servidor: ${response.body}');
      }
      setState(() => _brandPreview = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marca actualizada. El logo se regeneró y los tenants la aplicarán al entrar.')),
        );
      }
      await _fetchTenant();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingBrand = false);
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
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: DokkoTokens.text),
                onPressed: () => context.go('/super-admin/tenants'),
              ),
              const SizedBox(width: DokkoTokens.space8),
              Expanded(
                child: Text(
                  _tenant?['name'] ?? 'Cargando…',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: DokkoTokens.text,
                  ),
                ),
              ),
              DokkoButton(
                label: 'Entrar en modo soporte',
                isLoading: _enteringSupport,
                onPressed: _tenant != null ? _enterSupportMode : null,
              ),
            ],
          ),
          const SizedBox(height: DokkoTokens.space24),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_tenant == null)
            const Center(
              child: Text('No se encontró el tenant.',
                  style: TextStyle(color: DokkoTokens.text2)),
            )
          else
            ListView(
              shrinkWrap: true,
              children: [
                DokkoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(label: 'ID', value: _tenant!['id']),
                      _InfoRow(label: 'Nombre', value: _tenant!['name']),
                      _InfoRow(label: 'Módulo', value: _tenant!['module_slug']),
                      _InfoRow(
                        label: 'Propietario',
                        value: _tenant!['account_owners']?['email'] ?? 'Sin asignar',
                      ),
                      _InfoRow(
                        label: 'Email propietario',
                        value: _tenant!['account_owners']?['email'] ?? '—',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DokkoTokens.space24),
                _BrandCard(
                  tenantId: widget.tenantId,
                  brandConfig: _tenant!['brand_config'] as Map<String, dynamic>? ?? {},
                  preview: _brandPreview,
                  generating: _generatingBrand,
                  saving: _savingBrand,
                  onGenerate: _generateColorsFromLogo,
                  onSave: _saveBrand,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DokkoTokens.space8),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: const TextStyle(
                    color: DokkoTokens.text2, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: DokkoTokens.text, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _BrandCard extends StatelessWidget {
  final String tenantId;
  final Map<String, dynamic> brandConfig;
  final Map<String, dynamic>? preview;
  final bool generating;
  final bool saving;
  final VoidCallback onGenerate;
  final VoidCallback onSave;

  const _BrandCard({
    required this.tenantId,
    required this.brandConfig,
    required this.preview,
    required this.generating,
    required this.saving,
    required this.onGenerate,
    required this.onSave,
  });

  Color _hex(String raw, {Color fallback = const Color(0xFF3E63DD)}) {
    final cleaned = raw.replaceAll('#', '');
    final value = int.tryParse('FF$cleaned', radix: 16);
    return value != null ? Color(value) : fallback;
  }

  @override
  Widget build(BuildContext context) {
    final currentPrimary = _hex(brandConfig['primary_color'] as String? ?? '#3E63DD');
    final currentSecondary = _hex(brandConfig['secondary_color'] as String? ?? '#111113');
    final logoUrl = brandConfig['logo_url'] as String?;

    final previewPrimary = preview != null
        ? _hex(preview!['primary_color'] as String? ?? '#3E63DD')
        : null;
    final previewSecondary = preview != null
        ? _hex(preview!['secondary_color'] as String? ?? '#111113')
        : null;
    final level = preview?['level'] as String? ?? _levelFor(currentPrimary);
    final isPreviewValid = preview?['is_valid'] != false;
    final ratio = (preview?['primary_text_ratio'] as num?)?.toDouble() ??
        double.parse(contrastRatio(currentPrimary, pickTextColor(currentPrimary)).toStringAsFixed(2));

    return DokkoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Identidad de marca',
              style: const TextStyle(color: DokkoTokens.text, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: DokkoTokens.space8),
          Text(
            'Colores aplicados dinámicamente en el panel del tenant (FASE 23). El fallback automático '
            'elige texto blanco o negro para mantener contraste AA sin ajuste manual.',
            style: const TextStyle(color: DokkoTokens.text2, fontSize: 12),
          ),
          const SizedBox(height: DokkoTokens.space16),
          Row(
            children: [
              _Swatch(label: 'Primario', color: previewPrimary ?? currentPrimary),
              const SizedBox(width: DokkoTokens.space16),
              _Swatch(label: 'Secundario', color: previewSecondary ?? currentSecondary),
            ],
          ),
          const SizedBox(height: DokkoTokens.space16),
          _ContrastBadge(level: level, ratio: ratio, valid: isPreviewValid),
          const SizedBox(height: DokkoTokens.space16),
          Row(
            children: [
              DokkoButton(
                label: 'Generar colores desde el logo',
                variant: DokkoButtonVariant.secondary,
                isLoading: generating,
                onPressed: generating ? null : onGenerate,
              ),
              const SizedBox(width: DokkoTokens.space12),
              if (preview != null) ...[
                DokkoButton(
                  label: 'Guardar paleta',
                  isLoading: saving,
                  onPressed: saving ? null : onSave,
                ),
                const SizedBox(width: DokkoTokens.space8),
              ],
            ],
          ),
          if (logoUrl != null && logoUrl.isNotEmpty) ...[
            const SizedBox(height: DokkoTokens.space12),
            ClipRRect(
              borderRadius: BorderRadius.circular(DokkoTokens.radiusMd),
              child: Image.network(logoUrl, height: 48, fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const SizedBox()),
            ),
          ],
        ],
      ),
    );
  }

  String _levelFor(Color color) {
    final ratio = contrastRatio(color, pickTextColor(color));
    return ratio >= 7.0 ? 'AAA' : (ratio >= 4.5 ? 'AA' : 'FALLA');
  }
}

class _Swatch extends StatelessWidget {
  final String label;
  final Color color;
  const _Swatch({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final fg = pickTextColor(color);
    return Container(
      padding: const EdgeInsets.all(DokkoTokens.space12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(DokkoTokens.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${label.toUpperCase()} — #${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
            style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ContrastBadge extends StatelessWidget {
  final String level;
  final double ratio;
  final bool valid;
  const _ContrastBadge({required this.level, required this.ratio, required this.valid});

  @override
  Widget build(BuildContext context) {
    final color = valid ? const Color(0xFF1B873F) : const Color(0xFFC62828);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DokkoTokens.space12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(valid ? Icons.verified_rounded : Icons.warning_amber_rounded, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            'Contraste texto: $ratio:1 · Nivel $level ${valid ? '' : '(insuficiente)'}',
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
