import 'package:flutter/material.dart';
import '../theme/dokko_tokens.dart';

enum DokkoBadgeStatus { amber, red, green, gray }

class DokkoBadge extends StatelessWidget {
  final String label;
  final DokkoBadgeStatus status;

  const DokkoBadge({
    super.key,
    required this.label,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case DokkoBadgeStatus.amber:
        color = DokkoTokens.amber;
        break;
      case DokkoBadgeStatus.red:
        color = DokkoTokens.red;
        break;
      case DokkoBadgeStatus.green:
        color = DokkoTokens.green;
        break;
      case DokkoBadgeStatus.gray:
        color = DokkoTokens.text3;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: status == DokkoBadgeStatus.gray
            ? DokkoTokens.surface
            : color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(DokkoTokens.radiusSm),
        border: Border.all(
          color: status == DokkoBadgeStatus.gray
              ? DokkoTokens.line
              : color.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.05,
        ),
      ),
    );
  }
}
