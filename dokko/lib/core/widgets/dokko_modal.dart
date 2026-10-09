import 'package:flutter/material.dart';
import 'dart:ui';
import '../theme/dokko_tokens.dart';
import 'dokko_button.dart';

class DokkoModal extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget>? actions;
  final double maxWidth;

  const DokkoModal({
    super.key,
    required this.title,
    required this.content,
    this.actions,
    this.maxWidth = 480,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget content,
    List<Widget>? actions,
    double maxWidth = 480,
  }) {
    return showDialog<T>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      barrierDismissible: true,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Center(
            child: DokkoModal(
              title: title,
              content: content,
              actions: actions,
              maxWidth: maxWidth,
            ),
          ),
        );
      },
    );
  }

  static Future<bool> confirm({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Confirmar',
    String cancelLabel = 'Cancelar',
    bool isDestructive = false,
  }) async {
    final result = await show<bool>(
      context: context,
      title: title,
      maxWidth: 480,
      content: Text(
        message,
        style: const TextStyle(
          color: DokkoTokens.text2,
          fontSize: 14,
          height: 1.5,
        ),
      ),
      actions: [
        DokkoButton(
          label: cancelLabel,
          variant: DokkoButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        DokkoButton(
          label: confirmLabel,
          variant: DokkoButtonVariant.primary,
          // Destructive red styling could be added to DokkoButton in a future iteration
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: maxWidth,
        decoration: BoxDecoration(
          color: DokkoTokens.surface,
          borderRadius: BorderRadius.circular(DokkoTokens.radiusLg),
          border: Border.all(color: DokkoTokens.line),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                title,
                style: const TextStyle(
                  color: DokkoTokens.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: content,
            ),
            if (actions != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions!
                      .map((w) => Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: w,
                          ))
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
