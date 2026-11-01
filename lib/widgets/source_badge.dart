import 'package:flutter/material.dart';
import '../core/constants/trusted_sources.dart';

class SourceBadge extends StatelessWidget {
  final String sourceName;
  final bool showTrustIcon;
  final double fontSize;

  const SourceBadge({
    super.key,
    required this.sourceName,
    this.showTrustIcon = true,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTrusted = TrustedSourcesConfig.isTrusted(sourceName);
    final isDark = theme.brightness == Brightness.dark;

    final badgeBg = isTrusted
        ? (isDark ? const Color(0xFF0F172A) : const Color(0xFFF0FDF4))
        : (isDark ? const Color(0xFF1E2028) : const Color(0xFFF4F4F5));

    final badgeTextColor = isTrusted
        ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1))
        : theme.colorScheme.onSurface.withValues(alpha: 0.7);

    final borderColor = isTrusted
        ? (isDark ? const Color(0xFF0284C7).withValues(alpha: 0.6) : const Color(0xFFBAE6FD))
        : theme.colorScheme.outline.withValues(alpha: 0.4);

    final badgeContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: borderColor,
          width: 0.8,
        ),
        boxShadow: isTrusted && isDark
            ? [
                BoxShadow(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                  blurRadius: 6,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showTrustIcon && isTrusted) ...[
            Icon(
              Icons.verified_rounded,
              size: fontSize + 1,
              color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            sourceName.toUpperCase(),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: badgeTextColor,
            ),
          ),
        ],
      ),
    );

    if (isTrusted) {
      return Tooltip(
        message: 'Verified Primary Source: $sourceName',
        child: badgeContent,
      );
    }
    return badgeContent;
  }
}
