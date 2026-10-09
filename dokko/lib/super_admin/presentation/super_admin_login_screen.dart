import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/dokko_tokens.dart';
import '../../../core/widgets/dokko_button.dart';
import '../../../core/widgets/dokko_card.dart';
import '../../../core/widgets/dokko_input.dart';
import '../providers/super_admin_provider.dart';

class SuperAdminLoginScreen extends ConsumerStatefulWidget {
  const SuperAdminLoginScreen({super.key});

  @override
  ConsumerState<SuperAdminLoginScreen> createState() =>
      _SuperAdminLoginScreenState();
}

class _SuperAdminLoginScreenState extends ConsumerState<SuperAdminLoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _mfaCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _mfaCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    await ref
        .read(superAdminAuthProvider.notifier)
        .signIn(_emailCtrl.text.trim(), _passwordCtrl.text);
  }

  Future<void> _handleMfa() async {
    await ref
        .read(superAdminAuthProvider.notifier)
        .verifyMfaCode(_mfaCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(superAdminAuthProvider);

    // Redirigir tras autenticación exitosa
    ref.listen(superAdminAuthProvider, (prev, next) {
      if (next.step == SuperAdminAuthStep.authenticated) {
        context.go('/super-admin/tenants');
      }
    });

    return Scaffold(
      backgroundColor: DokkoTokens.bg,
      body: Center(
        child: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Badge identificador
              Container(
                margin: const EdgeInsets.only(bottom: DokkoTokens.space24),
                padding: const EdgeInsets.symmetric(
                    horizontal: DokkoTokens.space12, vertical: DokkoTokens.space8),
                decoration: BoxDecoration(
                  color: DokkoTokens.amber.withValues(alpha: 0.12),
                  border: Border.all(color: DokkoTokens.amber.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(DokkoTokens.radiusSm),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_rounded, size: 14, color: DokkoTokens.amber),
                    SizedBox(width: 6),
                    Text(
                      'ACCESO SUPER-ADMIN',
                      style: TextStyle(
                        color: DokkoTokens.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              DokkoCard(
                child: authState.step == SuperAdminAuthStep.needsMfa
                    ? _buildMfaForm(authState)
                    : _buildLoginForm(authState),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm(SuperAdminAuthState authState) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Administración',
          style: TextStyle(
            color: DokkoTokens.text,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DokkoTokens.space24),
        DokkoInput(
          label: 'Email',
          placeholder: 'admin@dokko.app',
          controller: _emailCtrl,
        ),
        const SizedBox(height: DokkoTokens.space16),
        DokkoInput(
          label: 'Contraseña',
          placeholder: '••••••••',
          controller: _passwordCtrl,
          obscureText: true,
          errorText: authState.step == SuperAdminAuthStep.error
              ? authState.errorMessage
              : null,
        ),
        const SizedBox(height: DokkoTokens.space24),
        DokkoButton(
          label: 'Iniciar sesión',
          isLoading: authState.isLoading,
          onPressed: _handleLogin,
        ),
        const SizedBox(height: DokkoTokens.space16),
        DokkoButton(
          label: '← Volver al login de tenants',
          variant: DokkoButtonVariant.ghost,
          onPressed: () => context.go('/login'),
        ),
      ],
    );
  }

  Widget _buildMfaForm(SuperAdminAuthState authState) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.lock_clock_rounded,
            size: 32, color: DokkoTokens.amber),
        const SizedBox(height: DokkoTokens.space16),
        const Text(
          'Verificación en dos pasos',
          style: TextStyle(
            color: DokkoTokens.text,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DokkoTokens.space8),
        const Text(
          'Ingresa el código de 6 dígitos de tu aplicación autenticadora.',
          style: TextStyle(color: DokkoTokens.text2, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DokkoTokens.space24),
        DokkoInput(
          label: 'Código TOTP',
          placeholder: '000000',
          controller: _mfaCtrl,
          errorText: authState.errorMessage,
        ),
        const SizedBox(height: DokkoTokens.space24),
        DokkoButton(
          label: 'Verificar',
          isLoading: authState.isLoading,
          onPressed: _handleMfa,
        ),
        const SizedBox(height: DokkoTokens.space12),
        DokkoButton(
          label: 'Volver atrás',
          variant: DokkoButtonVariant.ghost,
          onPressed: () =>
              ref.read(superAdminAuthProvider.notifier).reset(),
        ),
      ],
    );
  }
}
