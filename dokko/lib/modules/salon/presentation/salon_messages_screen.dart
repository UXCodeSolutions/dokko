import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/messaging/wa_deep_link.dart';
import '../../../core/theme/dokko_tokens.dart';
import '../../../core/widgets/dokko_empty_state.dart';
import '../data/models/salon_models.dart';
import '../data/salon_api.dart';

final salonPendingProvider = FutureProvider<List<MessageBatch>>((ref) {
  return ref.read(salonApiProvider).getMessagingPending();
});

final salonHistoryProvider = FutureProvider<List<OutboundMessage>>((ref) {
  return ref.read(salonApiProvider).getMessagingHistory();
});

class SalonMessagesScreen extends ConsumerStatefulWidget {
  const SalonMessagesScreen({super.key});

  @override
  ConsumerState<SalonMessagesScreen> createState() =>
      _SalonMessagesScreenState();
}

class _SalonMessagesScreenState extends ConsumerState<SalonMessagesScreen> {
  int _tab = 0; // 0 = Pendientes, 1 = Historial
  bool _opening = false;

  Future<void> _confirmBatch(MessageBatch batch) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final res = await ref.read(salonApiProvider).confirmBatch(batch.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lote confirmado (${res['updated']} mensajes).')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _opening = false);
        ref.invalidate(salonPendingProvider);
        ref.invalidate(salonHistoryProvider);
      }
    }
  }

  Future<void> _cancelBatch(MessageBatch batch) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DokkoTokens.surface,
        title: const Text('Descartar lote',
            style: TextStyle(color: DokkoTokens.text, fontSize: 18)),
        content: const Text(
          'Los mensajes de este lote no se enviarán.',
          style: TextStyle(color: DokkoTokens.text2, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar',
                style: TextStyle(color: DokkoTokens.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Descartar',
                style: TextStyle(color: DokkoTokens.red)),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      final res = await ref.read(salonApiProvider).cancelBatch(batch.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lote descartado (${res['updated']} mensajes).')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        ref.invalidate(salonPendingProvider);
        ref.invalidate(salonHistoryProvider);
      }
    }
  }

  void _openMessagesSettings() {
    showDialog(
      context: context,
      builder: (_) => const _MessagingSettingsDialog(),
    ).then((_) {
      if (mounted) {
        ref.invalidate(salonPendingProvider);
        ref.invalidate(salonHistoryProvider);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(salonPendingProvider);
    final historyAsync = ref.watch(salonHistoryProvider);

    return Scaffold(
      backgroundColor: DokkoTokens.bg,
      appBar: AppBar(
        title: const Text('Centro de Mensajes',
            style: TextStyle(color: DokkoTokens.text)),
        backgroundColor: DokkoTokens.surface,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Configuración de mensajería',
            icon: const Icon(Icons.settings_rounded, color: DokkoTokens.text2),
            onPressed: _openMessagesSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DokkoTokens.space16,
              DokkoTokens.space12,
              DokkoTokens.space16,
              DokkoTokens.space8,
            ),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Pendientes')),
                ButtonSegment(value: 1, label: Text('Historial')),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
              style: SegmentedButton.styleFrom(
                backgroundColor: DokkoTokens.surface,
                selectedBackgroundColor:
                    DokkoTokens.accentDefault.withValues(alpha: 0.15),
                foregroundColor: DokkoTokens.text2,
                selectedForegroundColor: DokkoTokens.accentDefault,
              ),
            ),
          ),
          Expanded(
            child: _tab == 0 ? _buildPending(pendingAsync) : _buildHistory(historyAsync),
          ),
        ],
      ),
    );
  }

  Widget _buildPending(AsyncValue<List<MessageBatch>> pendingAsync) {
    return pendingAsync.when(
      data: (batches) {
        if (batches.isEmpty) {
          return const DokkoEmptyState(
            key: ValueKey('salon-pending-list'),
            icon: Icons.mark_chat_unread_rounded,
            message:
                'No hay mensajes pendientes.\nLos recordatorios de cita aparecerán aquí para enviarlos por WhatsApp.',
          );
        }
        return ListView.builder(
          key: const ValueKey('salon-pending-list'),
          padding: const EdgeInsets.fromLTRB(
              DokkoTokens.space16, 4, DokkoTokens.space16, DokkoTokens.space16),
          itemCount: batches.length,
          itemBuilder: (context, i) => _BatchCard(
            batch: batches[i],
            opening: _opening,
            onConfirm: () => _confirmBatch(batches[i]),
            onCancel: () => _cancelBatch(batches[i]),
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: DokkoTokens.accentDefault),
      ),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildHistory(AsyncValue<List<OutboundMessage>> historyAsync) {
    return historyAsync.when(
      data: (messages) {
        if (messages.isEmpty) {
          return const DokkoEmptyState(
            key: ValueKey('salon-history-list'),
            icon: Icons.history_rounded,
            message: 'Aún no hay mensajes enviados o descartados.',
          );
        }
        return ListView.builder(
          key: const ValueKey('salon-history-list'),
          padding: const EdgeInsets.fromLTRB(
              DokkoTokens.space16, 4, DokkoTokens.space16, DokkoTokens.space16),
          itemCount: messages.length,
          itemBuilder: (context, i) {
            final m = messages[i];
            final sent = m.status == 'sent';
            return Container(
              margin: const EdgeInsets.only(bottom: DokkoTokens.space8),
              padding: const EdgeInsets.symmetric(
                  horizontal: DokkoTokens.space16, vertical: DokkoTokens.space12),
              decoration: BoxDecoration(
                color: DokkoTokens.surface,
                borderRadius: BorderRadius.circular(DokkoTokens.radiusMd),
                border: Border.all(color: DokkoTokens.line),
              ),
              child: Row(
                children: [
                  Icon(
                    sent ? Icons.done_all_rounded : Icons.cancel_outlined,
                    color: sent ? DokkoTokens.accentDefault : DokkoTokens.red,
                    size: 18,
                  ),
                  const SizedBox(width: DokkoTokens.space12),
                  Expanded(
                    child: Text(
                      m.recipientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: DokkoTokens.text,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5),
                    ),
                  ),
                  Text(
                    sent ? 'Enviado' : 'Descartado',
                    style: TextStyle(
                        color: sent ? DokkoTokens.text2 : DokkoTokens.red,
                        fontSize: 12),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: DokkoTokens.accentDefault),
      ),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _BatchCard extends ConsumerWidget {
  final MessageBatch batch;
  final bool opening;
  final Future<void> Function() onConfirm;
  final Future<void> Function() onCancel;

  const _BatchCard({
    required this.batch,
    required this.opening,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: DokkoTokens.space16),
      decoration: BoxDecoration(
        color: DokkoTokens.surface,
        borderRadius: BorderRadius.circular(DokkoTokens.radiusLg),
        border: Border.all(color: DokkoTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(DokkoTokens.space16,
                DokkoTokens.space12, DokkoTokens.space8, DokkoTokens.space8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: DokkoTokens.space8, vertical: 3),
                  decoration: BoxDecoration(
                    color: DokkoTokens.accentDefault.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${batch.sourceLabel} · ${batch.messages.length}',
                    style: const TextStyle(
                        color: DokkoTokens.accentDefault,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Descartar lote',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: DokkoTokens.red, size: 18),
                  onPressed: opening ? null : onCancel,
                ),
                const SizedBox(width: 4),
                ElevatedButton(
                  onPressed: opening ? null : onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DokkoTokens.accentDefault,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: DokkoTokens.space16, vertical: 8),
                    textStyle: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Confirmar lote'),
                ),
              ],
            ),
          ),
          ...batch.messages.map(
            (m) => _MessageTile(message: m, opening: opening),
          ),
          const SizedBox(height: DokkoTokens.space8),
        ],
      ),
    );
  }
}

class _MessageTile extends ConsumerWidget {
  final OutboundMessage message;
  final bool opening;

  const _MessageTile({required this.message, required this.opening});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          DokkoTokens.space16, DokkoTokens.space4, DokkoTokens.space16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: DokkoTokens.accentDefault.withValues(alpha: 0.12),
            foregroundColor: DokkoTokens.accentDefault,
            child: Text(
              message.recipientName.isNotEmpty
                  ? message.recipientName[0].toUpperCase()
                  : '?',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: DokkoTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.recipientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: DokkoTokens.text,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  message.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: DokkoTokens.text2, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: DokkoTokens.space8),
          IconButton(
            tooltip: 'Abrir en WhatsApp',
            key: const ValueKey('msg-open-wa'),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chat_bubble_rounded,
                color: DokkoTokens.accentDefault, size: 20),
            onPressed: opening
                ? null
                : () => openWaDeepLink(
                      ref,
                      phoneDigits: message.phone,
                      body: message.body,
                    ),
          ),
        ],
      ),
    );
  }
}

// ── Settings + plantillas ────────────────────────────────────────────────────

class _MessagingSettingsDialog extends ConsumerStatefulWidget {
  const _MessagingSettingsDialog();

  @override
  ConsumerState<_MessagingSettingsDialog> createState() =>
      _MessagingSettingsDialogState();
}

class _MessagingSettingsDialogState
    extends ConsumerState<_MessagingSettingsDialog> {
  late MessagingSettings _settings;
  final TextEditingController _feedbackUrlController = TextEditingController();
  bool _loaded = false;
  bool _saving = false;
  List<Map<String, dynamic>> _templates = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _feedbackUrlController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = ref.read(salonApiProvider);
    final settings = await api.getMessagingSettings();
    final templates = await api.getMessagingTemplates();
    if (!mounted) return;
    _feedbackUrlController.text = settings.feedbackUrl;
    setState(() {
      _settings = settings;
      _templates = templates;
      _loaded = true;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final toSave = MessagingSettings(
        remindersEnabled: _settings.remindersEnabled,
        reminderHoursBefore: _settings.reminderHoursBefore,
        feedbackEnabled: _settings.feedbackEnabled,
        feedbackUrl: _feedbackUrlController.text.trim(),
      );
      await ref.read(salonApiProvider).updateMessagingSettings(toSave);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuración guardada.')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _editTemplate(Map<String, dynamic> tpl) {
    showDialog(
      context: context,
      builder: (_) => _TemplateDialog(template: tpl),
    ).then((saved) {
      if (saved == true) _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Dialog(
        backgroundColor: DokkoTokens.surface,
        child: Padding(
          padding: EdgeInsets.all(DokkoTokens.space24),
          child: Center(
            child: CircularProgressIndicator(color: DokkoTokens.accentDefault),
          ),
        ),
      );
    }

    return Dialog(
      backgroundColor: DokkoTokens.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DokkoTokens.radiusLg)),
      child: Container(
        width: 480,
        constraints: const BoxConstraints(maxHeight: 560),
        padding: const EdgeInsets.all(DokkoTokens.space24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Mensajería por WhatsApp',
                  style: TextStyle(
                      color: DokkoTokens.text,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text(
                'El personal abre WhatsApp y envía; Dokko prepara el mensaje.',
                style: TextStyle(color: DokkoTokens.text3, fontSize: 12),
              ),
              const SizedBox(height: DokkoTokens.space16),
              SwitchListTile(
                value: _settings.remindersEnabled,
                onChanged: (v) => setState(() => _settings =
                    MessagingSettings(
                  remindersEnabled: v,
                  reminderHoursBefore: _settings.reminderHoursBefore,
                  feedbackEnabled: _settings.feedbackEnabled,
                  feedbackUrl: _settings.feedbackUrl,
                )),
                contentPadding: EdgeInsets.zero,
                title: const Text('Recordatorios de cita',
                    style:
                        TextStyle(color: DokkoTokens.text, fontSize: 14)),
                subtitle: const Text(
                  'Solo a clientes con consentimiento (Ley 172-13).',
                  style: TextStyle(color: DokkoTokens.text3, fontSize: 12),
                ),
                dense: true,
              ),
              Padding(
                padding: const EdgeInsets.only(left: DokkoTokens.space8),
                child: Row(
                  children: [
                    const Text('Enviar el recordatorio',
                        style: TextStyle(
                            color: DokkoTokens.text2, fontSize: 13)),
                    const Spacer(),
                    DropdownButton<int>(
                      value: _settings.reminderHoursBefore,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 12, child: Text('12 h antes')),
                        DropdownMenuItem(value: 24, child: Text('24 h antes')),
                        DropdownMenuItem(value: 48, child: Text('48 h antes')),
                        DropdownMenuItem(value: 72, child: Text('72 h antes')),
                      ],
                      onChanged: _settings.remindersEnabled
                          ? (v) => setState(() => _settings =
                              MessagingSettings(
                            remindersEnabled: _settings.remindersEnabled,
                            reminderHoursBefore: v ?? 24,
                            feedbackEnabled: _settings.feedbackEnabled,
                            feedbackUrl: _settings.feedbackUrl,
                          ))
                          : null,
                    ),
                  ],
                ),
              ),
              const Divider(height: DokkoTokens.space24),
              SwitchListTile(
                value: _settings.feedbackEnabled,
                onChanged: (v) => setState(() => _settings = MessagingSettings(
                  remindersEnabled: _settings.remindersEnabled,
                  reminderHoursBefore: _settings.reminderHoursBefore,
                  feedbackEnabled: v,
                  feedbackUrl: _settings.feedbackUrl,
                )),
                contentPadding: EdgeInsets.zero,
                title: const Text('Feedback post-servicio',
                    style:
                        TextStyle(color: DokkoTokens.text, fontSize: 14)),
                subtitle: const Text(
                  'Envía el enlace de encuesta al completar la cita.',
                  style: TextStyle(color: DokkoTokens.text3, fontSize: 12),
                ),
                dense: true,
              ),
              if (_settings.feedbackEnabled) ...[
                const SizedBox(height: DokkoTokens.space8),
                TextField(
                  controller: _feedbackUrlController,
                  decoration: const InputDecoration(
                    labelText: 'URL del formulario de feedback',
                    hintText: 'https://…',
                  ),
                  onChanged: (v) => setState(() => _settings = MessagingSettings(
                    remindersEnabled: _settings.remindersEnabled,
                    reminderHoursBefore: _settings.reminderHoursBefore,
                    feedbackEnabled: _settings.feedbackEnabled,
                    feedbackUrl: v,
                  )),
                ),
              ],
              const Divider(height: DokkoTokens.space24),
              Row(
                children: [
                  const Text('Plantillas',
                      style: TextStyle(
                          color: DokkoTokens.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: DokkoTokens.space8),
              ..._templates.map((t) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      t['label'] ?? t['key'],
                      style: const TextStyle(
                          color: DokkoTokens.text, fontSize: 13),
                    ),
                    subtitle: Text(
                      (t['body'] ?? '').replaceAll('\n', ' '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: DokkoTokens.text3, fontSize: 11),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit_rounded,
                          size: 18, color: DokkoTokens.text2),
                      onPressed: () => _editTemplate(t),
                    ),
                  )),
              const SizedBox(height: DokkoTokens.space16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar',
                        style: TextStyle(color: DokkoTokens.text2)),
                  ),
                  const SizedBox(width: DokkoTokens.space8),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DokkoTokens.accentDefault,
                      foregroundColor: Colors.white,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(color: Colors.white))
                        : const Text('Guardar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> template;

  const _TemplateDialog({required this.template});

  @override
  ConsumerState<_TemplateDialog> createState() => _TemplateDialogState();
}

class _TemplateDialogState extends ConsumerState<_TemplateDialog> {
  late final TextEditingController _label;
  late final TextEditingController _body;

  @override
  void initState() {
    super.initState();
    _label = TextEditingController(text: widget.template['label'] ?? '');
    _body = TextEditingController(text: widget.template['body'] ?? '');
  }

  @override
  void dispose() {
    _label.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      await ref.read(salonApiProvider).saveMessagingTemplate(
            key: widget.template['key'],
            label: _label.text.trim(),
            body: _body.text.trim(),
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: DokkoTokens.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DokkoTokens.radiusLg)),
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(DokkoTokens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Plantilla: ${widget.template['key']}',
                style: const TextStyle(
                    color: DokkoTokens.text,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: DokkoTokens.space16),
            TextField(
              controller: _label,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: DokkoTokens.space16),
            TextField(
              controller: _body,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Mensaje',
                hintText:
                    'Usa {{client}}, {{business}}, {{date}}, {{time}}, {{link}}',
              ),
            ),
            const SizedBox(height: DokkoTokens.space8),
            const Text(
              'Variables: {{client}} {{business}} {{date}} {{time}} {{link}}',
              style: TextStyle(color: DokkoTokens.text3, fontSize: 11),
            ),
            const SizedBox(height: DokkoTokens.space16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar',
                      style: TextStyle(color: DokkoTokens.text2)),
                ),
                const SizedBox(width: DokkoTokens.space8),
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DokkoTokens.accentDefault,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Guardar plantilla'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}