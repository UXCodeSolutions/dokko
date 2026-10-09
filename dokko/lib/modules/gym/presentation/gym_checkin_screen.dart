import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/dokko_tokens.dart';
import '../../../core/widgets/dokko_card.dart';
import '../data/gym_api.dart';

class GymCheckinScreen extends ConsumerStatefulWidget {
  const GymCheckinScreen({super.key});

  @override
  ConsumerState<GymCheckinScreen> createState() => _GymCheckinScreenState();
}

class _GymCheckinScreenState extends ConsumerState<GymCheckinScreen> {
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();

  List<dynamic> _allMembers = [];
  List<dynamic> _filteredMembers = [];
  List<dynamic> _todaysCheckins = [];

  bool _isLoadingMembers = true;
  bool _isLoadingCheckins = false;
  String? _successMessage;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoadingMembers = true);
    try {
      final api = ref.read(gymApiProvider);
      final members = await api.getMembers();
      final checkins = await api.getTodaysCheckins();
      if (!mounted) return;
      setState(() {
        _allMembers = members;
        _filteredMembers = [];
        _todaysCheckins = checkins;
        _isLoadingMembers = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMembers = false;
        _errorMessage = '❌ Error al cargar miembros: $e';
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchCtrl.text.toLowerCase();
    if (query.isEmpty) {
      setState(() => _filteredMembers = []);
      return;
    }
    setState(() {
      _filteredMembers = _allMembers.where((m) {
        final name = '${m['first_name']} ${m['last_name']}'.toLowerCase();
        final id = (m['id_number'] ?? '').toLowerCase();
        final phone = (m['phone'] ?? '').toLowerCase();
        return name.contains(query) || id.contains(query) || phone.contains(query);
      }).take(8).toList();
    });
  }

  Future<void> _doCheckIn(Map<String, dynamic> member) async {
    setState(() {
      _successMessage = null;
      _errorMessage = null;
      _isLoadingCheckins = true;
    });

    final status = member['status'] ?? 'active';
    if (status != 'active') {
      setState(() {
        _errorMessage =
            '⚠️ ${member['first_name']} tiene membresía ${_statusLabel(status)}';
        _isLoadingCheckins = false;
      });
      return;
    }

    try {
      final api = ref.read(gymApiProvider);
      await api.checkIn(member['id']);
      final checkins = await api.getTodaysCheckins();
      if (!mounted) return;
      setState(() {
        _todaysCheckins = checkins;
        _successMessage = '✅ Check-in registrado: ${member['first_name']} ${member['last_name']}';
        _filteredMembers = [];
        _searchCtrl.clear();
        _isLoadingCheckins = false;
      });
      _focusNode.requestFocus();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '❌ Error al registrar: $e';
        _isLoadingCheckins = false;
      });
    }
  }

  void _showQrDialog(Map<String, dynamic> member) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: DokkoTokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DokkoTokens.radiusLg),
          side: const BorderSide(color: DokkoTokens.line),
        ),
        child: Padding(
          padding: const EdgeInsets.all(DokkoTokens.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${member['first_name']} ${member['last_name']}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: DokkoTokens.text,
                ),
              ),
              const SizedBox(height: DokkoTokens.space16),
              Container(
                padding: const EdgeInsets.all(DokkoTokens.space16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(DokkoTokens.radiusMd),
                ),
                child: QrImageView(
                  data: member['id'],
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: DokkoTokens.space12),
              Text(
                'ID: ${member['id_number'] ?? member['id'].toString().substring(0, 8)}',
                style: const TextStyle(fontSize: 12, color: DokkoTokens.text2),
              ),
              const SizedBox(height: DokkoTokens.space16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'active':    return 'Activo';
      case 'expired':   return 'Vencida';
      case 'suspended': return 'Suspendida';
      case 'cancelled': return 'Cancelada';
      default:          return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':    return DokkoTokens.green;
      case 'expired':   return DokkoTokens.amber;
      case 'suspended': return DokkoTokens.red;
      default:          return DokkoTokens.text2;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DokkoTokens.bg,
      body: Padding(
        padding: const EdgeInsets.all(DokkoTokens.space24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Left: Search + Check-in ────────────────────────────────────
            SizedBox(
              width: 380,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Check-in',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: DokkoTokens.text,
                    ),
                  ),
                  const SizedBox(height: DokkoTokens.space8),
                  const Text(
                    'Busca al miembro por nombre, cédula o teléfono.',
                    style: TextStyle(fontSize: 13, color: DokkoTokens.text2),
                  ),
                  const SizedBox(height: DokkoTokens.space16),
                  // Search box
                  CallbackShortcuts(
                    bindings: {
                      const SingleActivator(LogicalKeyboardKey.escape): () {
                        _searchCtrl.clear();
                        setState(() => _filteredMembers = []);
                      },
                    },
                    child: TextField(
                      controller: _searchCtrl,
                      focusNode: _focusNode,
                      autofocus: true,
                      style: const TextStyle(
                          fontSize: 16, color: DokkoTokens.text),
                      decoration: InputDecoration(
                        hintText: 'Buscar miembro...',
                        hintStyle:
                            const TextStyle(color: DokkoTokens.text3),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: DokkoTokens.text2),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded,
                                    color: DokkoTokens.text2),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _filteredMembers = []);
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: DokkoTokens.surface,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(DokkoTokens.radiusMd),
                          borderSide:
                              const BorderSide(color: DokkoTokens.line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(DokkoTokens.radiusMd),
                          borderSide:
                              const BorderSide(color: DokkoTokens.line),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(DokkoTokens.radiusMd),
                          borderSide: const BorderSide(
                              color: DokkoTokens.accentDefault),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: DokkoTokens.space8),
                  // Feedback message
                  if (_successMessage != null)
                    _FeedbackBanner(
                        message: _successMessage!, isError: false),
                  if (_errorMessage != null)
                    _FeedbackBanner(message: _errorMessage!, isError: true),
                  const SizedBox(height: DokkoTokens.space8),
                  // Results list
                  if (_isLoadingCheckins)
                    const Center(child: CircularProgressIndicator())
                  else if (_filteredMembers.isNotEmpty)
                    Expanded(
                      child: DokkoCard(
                        padding: EdgeInsets.zero,
                        child: ListView.separated(
                          itemCount: _filteredMembers.length,
                          separatorBuilder: (context, index) => const Divider(
                              height: 1, color: DokkoTokens.line),
                          itemBuilder: (ctx, i) {
                            final m = _filteredMembers[i];
                            final status = m['status'] ?? 'active';
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: DokkoTokens.space16,
                                vertical: DokkoTokens.space4,
                              ),
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor: DokkoTokens.surface2,
                                child: Text(
                                  '${m['first_name'][0]}${m['last_name'][0]}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: DokkoTokens.text,
                                  ),
                                ),
                              ),
                              title: Text(
                                '${m['first_name']} ${m['last_name']}',
                                style: const TextStyle(
                                    fontSize: 14, color: DokkoTokens.text),
                              ),
                              subtitle: Text(
                                m['id_number'] ?? m['phone'] ?? '',
                                style: const TextStyle(
                                    fontSize: 12, color: DokkoTokens.text2),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _statusColor(status)
                                          .withValues(alpha: 0.1),
                                      borderRadius:
                                          BorderRadius.circular(100),
                                    ),
                                    child: Text(
                                      _statusLabel(status),
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: _statusColor(status)),
                                    ),
                                  ),
                                  const SizedBox(width: DokkoTokens.space8),
                                  IconButton(
                                    icon: const Icon(
                                        Icons.qr_code_rounded,
                                        color: DokkoTokens.text2,
                                        size: 18),
                                    onPressed: () => _showQrDialog(m),
                                    tooltip: 'Ver QR',
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                        Icons.login_rounded,
                                        color: DokkoTokens.green,
                                        size: 18),
                                    onPressed: () => _doCheckIn(m),
                                    tooltip: 'Registrar Check-in',
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    )
                  else if (_searchCtrl.text.isEmpty)
                    const Spacer(),
                ],
              ),
            ),
            const SizedBox(width: DokkoTokens.space24),
            // ── Right: Today's check-ins ───────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Check-ins Hoy (${_todaysCheckins.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: DokkoTokens.text,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded,
                            color: DokkoTokens.text2),
                        onPressed: _loadData,
                        tooltip: 'Actualizar',
                      ),
                    ],
                  ),
                  const SizedBox(height: DokkoTokens.space12),
                  Expanded(
                    child: DokkoCard(
                      padding: EdgeInsets.zero,
                      child: _isLoadingMembers
                          ? const Center(child: CircularProgressIndicator())
                          : _todaysCheckins.isEmpty
                              ? const Center(
                                  child: Text(
                                    'Sin check-ins registrados hoy.',
                                    style: TextStyle(
                                        color: DokkoTokens.text2,
                                        fontSize: 13),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: _todaysCheckins.length,
                                  separatorBuilder: (context, index) => const Divider(
                                      height: 1, color: DokkoTokens.line),
                                  itemBuilder: (ctx, i) {
                                    final c = _todaysCheckins[i];
                                    final time = DateTime.tryParse(
                                        c['checked_in_at'] ?? '');
                                    final timeStr = time != null
                                        ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
                                        : '—';
                                    final member =
                                        c['gym_members'] as Map? ?? {};
                                    final name = member.isNotEmpty
                                        ? '${member['first_name']} ${member['last_name']}'
                                        : 'Miembro';

                                    return ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: DokkoTokens.space16,
                                        vertical: DokkoTokens.space4,
                                      ),
                                      leading: CircleAvatar(
                                        radius: 16,
                                        backgroundColor:
                                            DokkoTokens.green.withValues(
                                                alpha: 0.15),
                                        child: const Icon(
                                            Icons.check_rounded,
                                            size: 16,
                                            color: DokkoTokens.green),
                                      ),
                                      title: Text(name,
                                          style: const TextStyle(
                                              fontSize: 14,
                                              color: DokkoTokens.text)),
                                      trailing: Text(
                                        timeStr,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: DokkoTokens.text2),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Feedback banner widget
// ─────────────────────────────────────────────────────────────────────────────
class _FeedbackBanner extends StatelessWidget {
  final String message;
  final bool isError;
  const _FeedbackBanner({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    final color = isError ? DokkoTokens.red : DokkoTokens.green;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: DokkoTokens.space8),
      padding: const EdgeInsets.symmetric(
          horizontal: DokkoTokens.space16, vertical: DokkoTokens.space12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(DokkoTokens.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        message,
        style: TextStyle(fontSize: 14, color: color),
      ),
    );
  }
}
