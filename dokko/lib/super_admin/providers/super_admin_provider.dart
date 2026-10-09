import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Estado de autenticación del super-admin, incluyendo el paso 2FA
enum SuperAdminAuthStep { idle, needsMfa, authenticated, error }

class SuperAdminAuthState {
  final SuperAdminAuthStep step;
  final String? factorId; // ID del factor MFA activo
  final String? errorMessage;
  final bool isLoading;
  final String? supportTenantId; // ID del tenant al que se está dando soporte

  const SuperAdminAuthState({
    this.step = SuperAdminAuthStep.idle,
    this.factorId,
    this.errorMessage,
    this.isLoading = false,
    this.supportTenantId,
  });

  SuperAdminAuthState copyWith({
    SuperAdminAuthStep? step,
    String? factorId,
    String? errorMessage,
    bool? isLoading,
    String? supportTenantId,
    bool clearSupportTenant = false,
  }) {
    return SuperAdminAuthState(
      step: step ?? this.step,
      factorId: factorId ?? this.factorId,
      errorMessage: errorMessage ?? this.errorMessage,
      isLoading: isLoading ?? this.isLoading,
      supportTenantId: clearSupportTenant ? null : (supportTenantId ?? this.supportTenantId),
    );
  }
}

final superAdminAuthProvider =
    NotifierProvider<SuperAdminAuthNotifier, SuperAdminAuthState>(
        SuperAdminAuthNotifier.new);

/// Verifica si el usuario actual tiene is_super_admin = true en su JWT
final isSuperAdminProvider = Provider<bool>((ref) {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return false;
  final appMeta = user.appMetadata;
  return appMeta['is_super_admin'] == true;
});

class SuperAdminAuthNotifier extends Notifier<SuperAdminAuthState> {
  @override
  SuperAdminAuthState build() => const SuperAdminAuthState();

  /// Paso 1: Login con email + password
  Future<void> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      // Verificar si es super-admin
      final user = Supabase.instance.client.auth.currentUser;
      final isSuperAdmin = user?.appMetadata['is_super_admin'] == true;

      if (!isSuperAdmin) {
        await Supabase.instance.client.auth.signOut();
        state = state.copyWith(
          isLoading: false,
          step: SuperAdminAuthStep.error,
          errorMessage: 'Acceso denegado. Esta cuenta no tiene privilegios de super-admin.',
        );
        return;
      }

      // Verificar si tiene MFA configurado
      final factors = await Supabase.instance.client.auth.mfa.listFactors();
      final totpFactor = factors.totp.where((f) => f.status == FactorStatus.verified).firstOrNull;

      if (totpFactor != null) {
        // Tiene MFA — solicitar código
        final challenge = await Supabase.instance.client.auth.mfa.challenge(
          factorId: totpFactor.id,
        );
        state = state.copyWith(
          isLoading: false,
          step: SuperAdminAuthStep.needsMfa,
          factorId: challenge.id,
        );
      } else {
        // No tiene MFA configurado aún — autenticar directamente
        // (en producción deberías forzar la configuración)
        state = state.copyWith(
          isLoading: false,
          step: SuperAdminAuthStep.authenticated,
        );
      }
    } catch (e) {
      // Registrar error en log si es necesario
      state = state.copyWith(
        isLoading: false,
        step: SuperAdminAuthStep.error,
        errorMessage: 'Error: ${e.toString()}',
      );
    }
  }

  /// Paso 2: Verificar código TOTP
  Future<void> verifyMfaCode(String code) async {
    if (state.factorId == null) return;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await Supabase.instance.client.auth.mfa.verify(
        factorId: state.factorId!,
        challengeId: state.factorId!,
        code: code,
      );
      state = state.copyWith(
        isLoading: false,
        step: SuperAdminAuthStep.authenticated,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Código incorrecto. Inténtalo de nuevo.',
      );
    }
  }

  void reset() {
    state = const SuperAdminAuthState();
  }

  /// Activa el modo soporte para un tenant específico y registra en audit_log
  Future<void> enterSupportMode(String tenantId, String tenantName) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      await Supabase.instance.client.from('audit_log').insert({
        'tenant_id': tenantId,
        'user_id': user.id,
        'action': 'super_admin_support_mode_start',
        'entity': 'tenant',
        'entity_id': tenantId,
        'metadata': {
          'tenant_name': tenantName,
          'admin_email': user.email,
        },
      });
    } catch (_) {
      // El registro en audit_log no bloquea el acceso
    }

    state = state.copyWith(supportTenantId: tenantId);
  }

  /// Desactiva el modo soporte
  Future<void> exitSupportMode() async {
    final tenantId = state.supportTenantId;
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && tenantId != null) {
      try {
        await Supabase.instance.client.from('audit_log').insert({
          'tenant_id': tenantId,
          'user_id': user.id,
          'action': 'super_admin_support_mode_end',
          'entity': 'tenant',
          'entity_id': tenantId,
          'metadata': {'admin_email': user.email},
        });
      } catch (_) {}
    }
    state = state.copyWith(clearSupportTenant: true);
  }
}
