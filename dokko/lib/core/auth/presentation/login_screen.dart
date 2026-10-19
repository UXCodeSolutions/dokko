import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/dokko_tokens.dart';
import '../../widgets/dokko_button.dart';
import '../../widgets/dokko_card.dart';
import '../../widgets/dokko_input.dart';
import 'package:go_router/go_router.dart';
import '../auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;

  Future<void> _handleLogin() async {
    setState(() => _error = null);
    try {
      await ref.read(authProvider.notifier).signIn(
        _emailController.text,
        _passwordController.text,
      );
    } catch (e) {
      setState(() {
        _error = "Correo o contraseña incorrectos.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: DokkoTokens.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: DokkoTokens.space16,
              vertical: DokkoTokens.space24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: DokkoCard(
                child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset(
                  'assets/images/dokkologos/dokkoLogoClaro.png',
                  height: 72,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: DokkoTokens.space24),
                const Text(
                  'Iniciar sesión',
                  style: TextStyle(
                    color: DokkoTokens.text,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: DokkoTokens.space24),
                DokkoInput(
                  label: 'Email',
                  placeholder: 'tu@correo.com',
                  controller: _emailController,
                ),
                const SizedBox(height: DokkoTokens.space16),
                DokkoInput(
                  label: 'Contraseña',
                  placeholder: '••••••••',
                  controller: _passwordController,
                  obscureText: true,
                  errorText: _error,
                ),
                const SizedBox(height: DokkoTokens.space24),
                DokkoButton(
                  label: 'Iniciar sesión',
                  isLoading: authState.isLoading,
                  onPressed: _handleLogin,
                ),
                const SizedBox(height: DokkoTokens.space16),
                DokkoButton(
                  label: '¿Olvidaste tu contraseña?',
                  variant: DokkoButtonVariant.ghost,
                  onPressed: () {
                    // TODO: Implementar reset de password
                  },
                ),
                const SizedBox(height: DokkoTokens.space16),
                DokkoButton(
                  label: 'Entrar como Super-Admin',
                  variant: DokkoButtonVariant.secondary,
                  onPressed: () => context.go('/super-admin/login'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);
  }
}
