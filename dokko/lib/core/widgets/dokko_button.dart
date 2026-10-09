import 'package:flutter/material.dart';
import '../theme/dokko_tokens.dart';

enum DokkoButtonVariant { primary, secondary, ghost, outline, danger }

class DokkoButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final DokkoButtonVariant variant;
  final bool isLoading;
  final bool isDisabled;

  const DokkoButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = DokkoButtonVariant.primary,
    this.isLoading = false,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool active = !isDisabled && !isLoading && onPressed != null;

    Color bg;
    Color border = Colors.transparent;
    Color text;

    switch (variant) {
      case DokkoButtonVariant.primary:
        bg = active
            ? DokkoTokens.text
            : DokkoTokens.text.withValues(alpha: 0.4);
        text = DokkoTokens.bg;
        break;
      case DokkoButtonVariant.secondary:
        bg = DokkoTokens.surface;
        border = DokkoTokens.lineStrong;
        text = active
            ? DokkoTokens.text2
            : DokkoTokens.text2.withValues(alpha: 0.4);
        break;
      case DokkoButtonVariant.ghost:
        bg = Colors.transparent;
        text = active
            ? DokkoTokens.text2
            : DokkoTokens.text2.withValues(alpha: 0.4);
        break;
      case DokkoButtonVariant.outline:
        bg = Colors.transparent;
        border = DokkoTokens.lineStrong;
        text = active
            ? DokkoTokens.text
            : DokkoTokens.text.withValues(alpha: 0.4);
        break;
      case DokkoButtonVariant.danger:
        bg = active
            ? DokkoTokens.red
            : DokkoTokens.red.withValues(alpha: 0.4);
        text = Colors.white;
        break;
    }

    return SizedBox(
      height: 34,
      child: variant == DokkoButtonVariant.ghost || variant == DokkoButtonVariant.outline
          ? TextButton(
              onPressed: active ? onPressed : null,
              style: TextButton.styleFrom(
                foregroundColor: text,
                padding: const EdgeInsets.symmetric(
                  horizontal: DokkoTokens.space12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DokkoTokens.radiusMd),
                ),
              ),
              child: _buildContent(text),
            )
          : ElevatedButton(
              onPressed: active ? onPressed : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: bg,
                foregroundColor: text,
                elevation: 0,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(
                  horizontal: DokkoTokens.space12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DokkoTokens.radiusMd),
                  side: border != Colors.transparent
                      ? BorderSide(color: border)
                      : BorderSide.none,
                ),
              ),
              child: _buildContent(text),
            ),
    );
  }

  Widget _buildContent(Color textColor) {
    if (isLoading) {
      return SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(textColor),
        ),
      );
    }
    return Text(
      label,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textColor,
        fontFamily: 'Inter',
      ),
    );
  }
}
