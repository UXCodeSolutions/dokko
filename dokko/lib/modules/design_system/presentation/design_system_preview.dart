import 'package:flutter/material.dart';
import '../../../core/theme/dokko_tokens.dart';
import '../../../core/widgets/dokko_button.dart';
import '../../../core/widgets/dokko_input.dart';
import '../../../core/widgets/dokko_card.dart';
import '../../../core/widgets/dokko_badge.dart';
import '../../../core/widgets/dokko_modal.dart';
import '../../../core/widgets/dokko_empty_state.dart';
import '../../../core/widgets/dokko_skeleton.dart';
import '../../../core/widgets/dokko_table.dart';

class DesignSystemPreview extends StatelessWidget {
  const DesignSystemPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DokkoTokens.bg,
      appBar: AppBar(
        title: const Text('Dokko Design System Preview', style: TextStyle(color: DokkoTokens.text)),
        backgroundColor: DokkoTokens.surface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: DokkoTokens.line, height: 1),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(DokkoTokens.space24),
        children: [
          _buildSection('1. Botones (DokkoButton)', [
            Row(
              children: [
                DokkoButton(label: 'Primary', onPressed: () {}),
                const SizedBox(width: 8),
                DokkoButton(label: 'Secondary', variant: DokkoButtonVariant.secondary, onPressed: () {}),
                const SizedBox(width: 8),
                DokkoButton(label: 'Ghost', variant: DokkoButtonVariant.ghost, onPressed: () {}),
                const SizedBox(width: 8),
                DokkoButton(label: 'Loading', isLoading: true, onPressed: () {}),
                const SizedBox(width: 8),
                const DokkoButton(label: 'Disabled', isDisabled: true),
              ],
            )
          ]),
          _buildSection('2. Inputs (DokkoInput)', [
            Row(
              children: [
                Expanded(child: DokkoInput(label: 'Normal Input', placeholder: 'Escribe aquí...')),
                const SizedBox(width: 16),
                Expanded(child: DokkoInput(label: 'Error Input', placeholder: 'Algo salió mal', errorText: 'Este campo es requerido')),
              ],
            )
          ]),
          _buildSection('3. Badges (DokkoBadge)', [
            const Row(
              children: [
                DokkoBadge(label: 'Activo', status: DokkoBadgeStatus.green),
                SizedBox(width: 8),
                DokkoBadge(label: 'Pendiente', status: DokkoBadgeStatus.amber),
                SizedBox(width: 8),
                DokkoBadge(label: 'Vencido', status: DokkoBadgeStatus.red),
                SizedBox(width: 8),
                DokkoBadge(label: 'Borrador', status: DokkoBadgeStatus.gray),
              ],
            )
          ]),
          _buildSection('4. Modales (DokkoModal)', [
            Row(
              children: [
                DokkoButton(
                  label: 'Abrir Modal',
                  variant: DokkoButtonVariant.secondary,
                  onPressed: () {
                    DokkoModal.show(
                      context: context,
                      title: 'Nuevo Miembro',
                      content: const Text('Formulario de ejemplo para agregar miembro.', style: TextStyle(color: DokkoTokens.text2)),
                      actions: [
                        DokkoButton(label: 'Cancelar', variant: DokkoButtonVariant.secondary, onPressed: () => Navigator.pop(context)),
                        DokkoButton(label: 'Guardar', onPressed: () => Navigator.pop(context)),
                      ],
                    );
                  },
                ),
                const SizedBox(width: 8),
                DokkoButton(
                  label: 'Abrir Confirmación',
                  variant: DokkoButtonVariant.secondary,
                  onPressed: () async {
                    await DokkoModal.confirm(
                      context: context,
                      title: 'Eliminar Registro',
                      message: '¿Estás seguro de que deseas eliminar este registro de manera permanente?',
                      confirmLabel: 'Eliminar',
                    );
                  },
                ),
              ],
            )
          ]),
          _buildSection('5. Empty States & Skeletons', [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: DokkoCard(
                    child: DokkoEmptyState(
                      icon: Icons.group_outlined,
                      message: 'Aún no tienes miembros registrados.',
                      actionLabel: 'Registrar Miembro',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DokkoCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        DokkoSkeleton(height: 24, width: 150),
                        SizedBox(height: 16),
                        DokkoSkeleton(height: 16, width: double.infinity),
                        SizedBox(height: 8),
                        DokkoSkeleton(height: 16, width: double.infinity),
                      ],
                    ),
                  ),
                ),
              ],
            )
          ]),
          _buildSection('6. Tabla (DokkoTable)', [
            SizedBox(
              height: 300,
              child: DokkoCard(
                padding: EdgeInsets.zero,
                child: DokkoTable<Map<String, dynamic>>(
                  selectable: true,
                  columns: [
                    const DokkoTableColumn(title: 'Nombre', flex: 2),
                    DokkoTableColumn(title: 'Estado', width: 100, customRender: (item) {
                      return DokkoBadge(label: item['status'] == DokkoBadgeStatus.green ? 'Activo' : (item['status'] == DokkoBadgeStatus.amber ? 'Pend' : 'Deuda'), status: item['status']);
                    }),
                    const DokkoTableColumn(title: 'Deuda', width: 100),
                  ],
                  data: const [
                    {'name': 'Jean Rodriguez', 'status': DokkoBadgeStatus.green, 'debt': '\$0'},
                    {'name': 'Ana Perez', 'status': DokkoBadgeStatus.amber, 'debt': '\$50'},
                    {'name': 'Luis Gomez', 'status': DokkoBadgeStatus.red, 'debt': '\$120'},
                  ],
                  cellValue: (item, index) {
                    if (index == 0) return item['name'];
                    if (index == 2) return item['debt'];
                    return '';
                  },
                  onRowTap: (item) {},
                ),
              ),
            )
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: DokkoTokens.text, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: DokkoTokens.space16),
        ...children,
        const SizedBox(height: DokkoTokens.space40),
      ],
    );
  }
}
