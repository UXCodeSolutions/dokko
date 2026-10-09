import 'package:flutter/material.dart';
import '../theme/dokko_tokens.dart';
import 'dokko_button.dart';

class DokkoEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const DokkoEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 24,
            color: DokkoTokens.text3,
          ),
          const SizedBox(height: DokkoTokens.space16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: DokkoTokens.text2,
              fontSize: 14,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: DokkoTokens.space24),
            DokkoButton(
              label: actionLabel!,
              onPressed: onAction,
            ),
          ]
        ],
      ),
    );
  }
}
