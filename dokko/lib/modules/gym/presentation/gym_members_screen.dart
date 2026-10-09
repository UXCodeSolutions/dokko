import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/dokko_tokens.dart';
import '../../../core/widgets/dokko_button.dart';
import '../../../core/widgets/dokko_card.dart';
import '../../../core/widgets/dokko_empty_state.dart';
import '../../../core/widgets/dokko_table.dart';
import '../providers/gym_provider.dart';

class GymMembersScreen extends ConsumerStatefulWidget {
  const GymMembersScreen({super.key});

  @override
  ConsumerState<GymMembersScreen> createState() => _GymMembersScreenState();
}

class _GymMembersScreenState extends ConsumerState<GymMembersScreen> {
  String _query = '';
  String? _statusFilter; // null = todos

  static const _statusOptions = [
    (null, 'Todos'),
    ('active', 'Activos'),
    ('expired', 'Vencidos'),
    ('suspended', 'Suspendidos'),
    ('cancelled', 'Cancelados'),
  ];

  String _statusLabel(String status) {
    switch (status) {
      case 'active':    return 'Activo';
      case 'expired':   return 'Vencido';
      case 'suspended': return 'Suspendido';
      case 'cancelled': return 'Cancelado';
      default:          return status;
    }
  }

  bool _matches(dynamic member) {
    final status = (member['status'] ?? 'active').toString();
    if (_statusFilter != null && status != _statusFilter) return false;

    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final name =
        '${member['first_name']} ${member['last_name']}'.toLowerCase();
    final email = (member['email'] ?? '').toString().toLowerCase();
    final phone = (member['phone'] ?? '').toString().toLowerCase();
    return name.contains(q) || email.contains(q) || phone.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(gymMembersProvider);

    return Scaffold(
      backgroundColor: DokkoTokens.bg,
      body: Padding(
        padding: const EdgeInsets.all(DokkoTokens.space24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Miembros',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: DokkoTokens.text,
                  ),
                ),
                DokkoButton(
                  label: 'Nuevo Miembro',
                  onPressed: () => context.push('/gym/members/new'),
                ),
              ],
            ),
            const SizedBox(height: DokkoTokens.space16),
            _FilterBar(
              query: _query,
              statusFilter: _statusFilter,
              onQueryChanged: (v) => setState(() => _query = v),
              onStatusChanged: (v) => setState(() => _statusFilter = v),
            ),
            const SizedBox(height: DokkoTokens.space16),
            Expanded(
              child: DokkoCard(
                padding: EdgeInsets.zero,
                child: membersAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(
                    child: Text('Error: $err',
                        style: const TextStyle(color: Colors.red)),
                  ),
                  data: (members) {
                    final filtered =
                        members.where((m) => _matches(m)).toList();
                    if (filtered.isEmpty) {
                      return DokkoEmptyState(
                        icon: members.isEmpty
                            ? Icons.group_off_rounded
                            : Icons.search_off_rounded,
                        message: members.isEmpty
                            ? 'No hay miembros registrados.\nPresiona "Nuevo Miembro" para añadir uno.'
                            : 'Ningún miembro coincide con el filtro.',
                      );
                    }
                    return DokkoTable<dynamic>(
                      columns: const [
                        DokkoTableColumn(title: 'Nombre', flex: 2),
                        DokkoTableColumn(title: 'Email', flex: 2),
                        DokkoTableColumn(title: 'Teléfono', flex: 1),
                        DokkoTableColumn(title: 'Estado', width: 110),
                        DokkoTableColumn(title: 'Vence', width: 110),
                      ],
                      data: filtered,
                      onRowTap: (item) =>
                          context.push('/gym/members/${item['id']}'),
                      cellValue: (item, index) {
                        switch (index) {
                          case 0:
                            return '${item['first_name']} ${item['last_name']}';
                          case 1:
                            return item['email'] ?? '—';
                          case 2:
                            return item['phone'] ?? '—';
                          case 3:
                            return _statusLabel(item['status'] ?? 'active');
                          case 4:
                            return item['membership_expires_at'] ?? '—';
                          default:
                            return '';
                        }
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String query;
  final String? statusFilter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String?> onStatusChanged;

  const _FilterBar({
    required this.query,
    required this.statusFilter,
    required this.onQueryChanged,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          onChanged: onQueryChanged,
          decoration: InputDecoration(
            hintText: 'Buscar por nombre, email o teléfono…',
            hintStyle:
                const TextStyle(color: DokkoTokens.text3, fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded,
                size: 18, color: DokkoTokens.text3),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded,
                        size: 16, color: DokkoTokens.text3),
                    onPressed: () => onQueryChanged(''),
                  ),
            filled: true,
            fillColor: DokkoTokens.surface,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(vertical: DokkoTokens.space8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DokkoTokens.radiusMd),
              borderSide: const BorderSide(color: DokkoTokens.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DokkoTokens.radiusMd),
              borderSide: const BorderSide(color: DokkoTokens.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DokkoTokens.radiusMd),
              borderSide: const BorderSide(
                  color: DokkoTokens.accentDefault, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: DokkoTokens.space12),
        Wrap(
          spacing: DokkoTokens.space8,
          runSpacing: DokkoTokens.space8,
          children: _GymMembersScreenState._statusOptions.map((opt) {
            return _StatusChip(
              label: opt.$2,
              selected: statusFilter == opt.$1,
              onTap: () => onStatusChanged(opt.$1),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? DokkoTokens.accentDefault : DokkoTokens.text2;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: DokkoTokens.space12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? DokkoTokens.accentDefault.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? DokkoTokens.accentDefault.withValues(alpha: 0.4)
                : DokkoTokens.line,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}