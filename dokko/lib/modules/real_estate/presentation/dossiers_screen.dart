import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/dokko_tokens.dart';
import '../../../core/widgets/dokko_empty_state.dart';

class DossiersScreen extends ConsumerWidget {
  const DossiersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: DokkoTokens.bg,
      appBar: AppBar(
        title: const Text('Dossiers', style: TextStyle(color: DokkoTokens.text)),
        backgroundColor: DokkoTokens.surface,
        elevation: 0,
      ),
      body: const DokkoEmptyState(
        icon: Icons.description_outlined,
        message: 'Aún no has generado ningún dossier o presentación de propiedades.\nEsta función estará disponible en la Fase 21.',
      ),
    );
  }
}
