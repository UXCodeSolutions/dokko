import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../../../core/api/api_provider.dart';
import '../../../core/theme/dokko_tokens.dart';
import '../../../core/widgets/dokko_button.dart';
import '../../../core/widgets/dokko_input.dart';

class DeleteTenantDialog extends ConsumerStatefulWidget {
  final String tenantId;
  final String tenantName;
  final Future<void> Function()? onDeleted;

  const DeleteTenantDialog({
    super.key,
    required this.tenantId,
    required this.tenantName,
    this.onDeleted,
  });

  static Future<void> show(
    BuildContext context, {
    required String tenantId,
    required String tenantName,
    Future<void> Function()? onDeleted,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DeleteTenantDialog(
        tenantId: tenantId,
        tenantName: tenantName,
        onDeleted: onDeleted,
      ),
    );
  }

  @override
  ConsumerState<DeleteTenantDialog> createState() => _DeleteTenantDialogState();
}

class _DeleteTenantDialogState extends ConsumerState<DeleteTenantDialog> {
  final _controller = TextEditingController();
  bool _isDeleting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isConfirmed => _controller.text.trim() == 'CONFIRMAR';

  Future<void> _handleDelete() async {
    if (!_isConfirmed || _isDeleting) return;

    setState(() {
      _isDeleting = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      await api.delete('/super-admin/tenants/${widget.tenantId}');

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('La empresa "${widget.tenantName}" ha sido eliminada permanentemente.'),
          backgroundColor: DokkoTokens.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      if (widget.onDeleted != null) {
        await widget.onDeleted!();
      }
    } on HttpException catch (e) {
      if (!mounted) return;
      setState(() {
        _isDeleting = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDeleting = false;
        _error = 'Ocurrió un error al intentar eliminar el tenant. Verifica tu conexión.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 440,
        decoration: BoxDecoration(
          color: DokkoTokens.bg,
          borderRadius: BorderRadius.circular(DokkoTokens.radiusLg),
          border: Border.all(color: DokkoTokens.line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        padding: const EdgeInsets.all(DokkoTokens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera con icono de peligro
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: DokkoTokens.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(DokkoTokens.radiusMd),
                    border: Border.all(color: DokkoTokens.red.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(
                    Icons.delete_forever_rounded,
                    color: DokkoTokens.red,
                    size: 24,
                  ),
                ),
                const SizedBox(width: DokkoTokens.space12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Eliminar Empresa / Tenant',
                        style: TextStyle(
                          color: DokkoTokens.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Esta acción es destructiva e irreversible',
                        style: TextStyle(
                          color: DokkoTokens.red,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: DokkoTokens.space20),

            // Mensaje explicativo
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: DokkoTokens.text2,
                  fontSize: 13.5,
                  height: 1.45,
                ),
                children: [
                  const TextSpan(text: '¿Estás seguro de que deseas eliminar permanentemente '),
                  TextSpan(
                    text: widget.tenantName,
                    style: const TextStyle(
                      color: DokkoTokens.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const TextSpan(
                    text:
                        '? Se eliminarán la empresa, su usuario administrador, registros de auditoría y todos los módulos asociados de forma permanente.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: DokkoTokens.space16),

            // Recuadro de instrucción de seguridad
            Container(
              padding: const EdgeInsets.all(DokkoTokens.space12),
              decoration: BoxDecoration(
                color: DokkoTokens.surface,
                borderRadius: BorderRadius.circular(DokkoTokens.radiusSm),
                border: Border.all(color: DokkoTokens.lineStrong),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: DokkoTokens.text3),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(color: DokkoTokens.text2, fontSize: 12.5),
                        children: [
                          TextSpan(text: 'Para confirmar, escribe '),
                          TextSpan(
                            text: 'CONFIRMAR',
                            style: TextStyle(
                              color: DokkoTokens.text,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          TextSpan(text: ' a continuación:'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DokkoTokens.space16),

            // Campo de entrada
            DokkoInput(
              label: 'Confirmación de seguridad',
              placeholder: 'CONFIRMAR',
              controller: _controller,
              onChanged: (_) => setState(() {}),
            ),

            if (_error != null) ...[
              const SizedBox(height: DokkoTokens.space12),
              Text(
                _error!,
                style: const TextStyle(
                  color: DokkoTokens.red,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],

            const SizedBox(height: DokkoTokens.space24),

            // Botones de acción
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                DokkoButton(
                  label: 'Cancelar',
                  variant: DokkoButtonVariant.secondary,
                  onPressed: _isDeleting ? null : () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: DokkoTokens.space12),
                DokkoButton(
                  label: 'Eliminar definitivamente',
                  variant: DokkoButtonVariant.danger,
                  isDisabled: !_isConfirmed,
                  isLoading: _isDeleting,
                  onPressed: _handleDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
