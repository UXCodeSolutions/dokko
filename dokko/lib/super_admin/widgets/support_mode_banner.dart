import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/dokko_tokens.dart';
import '../providers/super_admin_provider.dart';

class SupportModeBanner extends ConsumerWidget {
  const SupportModeBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminState = ref.watch(superAdminAuthProvider);
    if (adminState.supportTenantId == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: DokkoTokens.space16,
        vertical: DokkoTokens.space8,
      ),
      decoration: BoxDecoration(
        color: DokkoTokens.amber.withValues(alpha: 0.15),
        border: const Border(
          bottom: BorderSide(color: DokkoTokens.amber, width: 1),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.support_agent_rounded,
              size: 15, color: DokkoTokens.amber),
          const SizedBox(width: 8),
          const Text(
            'MODO SOPORTE ACTIVO — Estás viendo la cuenta de un tenant.',
            style: TextStyle(
              color: DokkoTokens.amber,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () async {
              await ref
                  .read(superAdminAuthProvider.notifier)
                  .exitSupportMode();
              if (context.mounted) {
                context.go('/super-admin/tenants');
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: DokkoTokens.amber),
                borderRadius: BorderRadius.circular(DokkoTokens.radiusSm),
              ),
              child: const Text(
                'Salir del modo soporte',
                style: TextStyle(
                  color: DokkoTokens.amber,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
