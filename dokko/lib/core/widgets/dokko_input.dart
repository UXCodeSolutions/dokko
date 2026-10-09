import 'package:flutter/material.dart';
import '../theme/dokko_tokens.dart';

class DokkoInput extends StatelessWidget {
  final String label;
  final String? placeholder;
  final String? errorText;
  final bool obscureText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final int? maxLines;

  const DokkoInput({
    super.key,
    required this.label,
    this.placeholder,
    this.errorText,
    this.obscureText = false,
    this.controller,
    this.onChanged,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    final isMultiline = maxLines != null && maxLines! > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: DokkoTokens.text2,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: DokkoTokens.space4),
        SizedBox(
          height: isMultiline ? null : 36,
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            onChanged: onChanged,
            maxLines: maxLines ?? 1,
            style: const TextStyle(
              fontSize: 14,
              color: DokkoTokens.text,
              fontFamily: 'Inter',
            ),
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: const TextStyle(
                color: DokkoTokens.text3,
                fontSize: 14,
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: DokkoTokens.space12,
                vertical: isMultiline ? DokkoTokens.space8 : 0,
              ),
              filled: true,
              fillColor: DokkoTokens.surface,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DokkoTokens.radiusMd),
                borderSide: BorderSide(
                  color: errorText != null ? DokkoTokens.red : DokkoTokens.line,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DokkoTokens.radiusMd),
                borderSide: BorderSide(
                  color: errorText != null ? DokkoTokens.red : DokkoTokens.accentDefault,
                ),
              ),
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              errorText!,
              style: const TextStyle(
                fontSize: 11.5,
                color: DokkoTokens.red,
                fontFamily: 'Inter',
              ),
            ),
          ),
      ],
    );
  }
}
