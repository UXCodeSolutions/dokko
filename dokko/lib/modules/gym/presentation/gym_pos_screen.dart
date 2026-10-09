import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared_components/pos/pos_data_source.dart';
import '../../../shared_components/pos/pos_screen.dart';

/// Pantalla POS del módulo Gym: envoltura del componente POS compartido con
/// el catálogo de productos del gimnasio (FASE 13).
class GymPosScreen extends ConsumerWidget {
  const GymPosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PosScreen(dataSource: ref.watch(gymPosDataSourceProvider));
  }
}