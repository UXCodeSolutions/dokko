import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../modules/module_definition.dart';
import '../modules/available_modules.dart';
import '../auth/auth_provider.dart';

/// Modelo que representa los datos del tenant activo
class TenantData {
  final String tenantId;
  final String name;
  final String moduleSlug;
  final String status;
  final Color accentColor;
  final Color secondaryColor;
  final String? logoUrl;

  const TenantData({
    required this.tenantId,
    required this.name,
    required this.moduleSlug,
    required this.status,
    required this.accentColor,
    required this.secondaryColor,
    this.logoUrl,
  });

  bool get isActive => status == 'active';
}

/// Provider que expone el tenant activo y su módulo
final tenantProvider = AsyncNotifierProvider<TenantNotifier, TenantData?>(TenantNotifier.new);

/// Provider de conveniencia para obtener el módulo activo
final activeModuleProvider = Provider<ModuleDefinition?>((ref) {
  final tenant = ref.watch(tenantProvider).value;
  if (tenant == null) return null;
  return getModule(tenant.moduleSlug);
});

class TenantNotifier extends AsyncNotifier<TenantData?> {
  @override
  Future<TenantData?> build() async {
    // Re-ejecutar cuando cambie la sesión (login/logout).
    final user = ref.watch(authProvider).value;
    if (user == null) return null;
    return _fetchTenantData(user.id);
  }

  Future<TenantData?> _fetchTenantData(String userId) async {
    try {
      // 1. Buscar el tenant_id del usuario en tenant_users
      final tuResponse = await Supabase.instance.client
          .from('tenant_users')
          .select('tenant_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (tuResponse == null) return null;

      final tenantId = tuResponse['tenant_id'] as String;

      // 2. Buscar el tenant completo
      final tenantResponse = await Supabase.instance.client
          .from('tenants')
          .select('id, name, module_slug, brand_config, status')
          .eq('id', tenantId)
          .single();

      // 3. Extraer el color primario del brand_config
      final brandConfig = tenantResponse['brand_config'] as Map<String, dynamic>? ?? {};
      final primaryColorHex = brandConfig['primary_color'] as String? ?? '#3E63DD';
      final secondaryColorHex = brandConfig['secondary_color'] as String? ?? '#111113';
      final accentColor = _hexToColor(primaryColorHex);
      final secondaryColor = _hexToColor(secondaryColorHex, fallback: const Color(0xFF111113));

      return TenantData(
        tenantId: tenantResponse['id'] as String,
        name: tenantResponse['name'] as String,
        moduleSlug: tenantResponse['module_slug'] as String,
        status: tenantResponse['status'] as String? ?? 'active',
        accentColor: accentColor,
        secondaryColor: secondaryColor,
        logoUrl: brandConfig['logo_url'] as String?,
      );
    } catch (e) {
      return null;
    }
  }

  /// Recarga los datos del tenant (útil tras login)
  Future<void> reload() async {
    state = const AsyncLoading();
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      state = const AsyncData(null);
      return;
    }
    state = AsyncData(await _fetchTenantData(user.id));
  }

  Color _hexToColor(String hex, {Color fallback = const Color(0xFF3E63DD)}) {
    final cleaned = hex.replaceAll('#', '');
    final value = int.tryParse('FF$cleaned', radix: 16);
    return value != null ? Color(value) : fallback;
  }
}
