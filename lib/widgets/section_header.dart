import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onActionTap;
  final String? actionLabel;
  final IconData? icon;
  final Color? accentColor;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onActionTap,
    this.actionLabel,
    this.icon,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final effectiveAccent = accentColor ?? theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3.5,
                height: 18,
                decoration: BoxDecoration(
                  color: effectiveAccent,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: isDark
                      ? [
                          BoxShadow(
                            color: effectiveAccent.withValues(alpha: 0.6),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 18,
                  color: effectiveAccent,
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (onActionTap != null)
                TextButton(
                  onPressed: onActionTap,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        actionLabel ?? 'SEE ALL',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          color: effectiveAccent,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 14,
                        color: effectiveAccent,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Divider(
            height: 1,
            thickness: 1,
            color: theme.colorScheme.outline.withValues(alpha: 0.6),
          ),
        ],
      ),
    );
  }
}
