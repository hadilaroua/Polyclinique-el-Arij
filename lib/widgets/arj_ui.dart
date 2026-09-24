import 'package:flutter/material.dart';
import '../utils/theme.dart';

/// Premium iOS-style shared UI components — Figma Design System
class ArjUi {
  // ── Status badge ──────────────────────────────────────────────────────────
  static Widget statusBadge(
    String label, {
    Color? color,
    Color? textColor,
    double fontSize = 11,
    EdgeInsets? padding,
  }) {
    final bg = color ?? AppTheme.danger;
    final fg = textColor ?? Colors.white;
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  // ── Chip filter button ─────────────────────────────────────────────────────
  static Widget filterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? selectedColor,
    BuildContext? context,
  }) {
    final selColor = selectedColor ?? AppTheme.purple;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? selColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? selColor : AppTheme.border,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }

  // ── Section header ─────────────────────────────────────────────────────────
  static Widget sectionHeader(
    BuildContext context,
    String title, {
    String? action,
    VoidCallback? onAction,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppTheme.textColor(context),
            letterSpacing: -0.3,
          ),
        ),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              action,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.purpleColor(context),
              ),
            ),
          ),
      ],
    );
  }

  // ── Search bar ─────────────────────────────────────────────────────────────
  static Widget searchBar(
    BuildContext context, {
    required String hint,
    required ValueChanged<String> onChanged,
    Widget? trailing,
    TextEditingController? controller,
  }) {
    final isDark = AppTheme.isDarkMode(context);
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkElevated : const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(Icons.search_rounded, size: 20, color: AppTheme.subtextColor(context)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.textColor(context),
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  fontSize: 15,
                  color: AppTheme.subtextColor(context),
                ),
                border: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
          if (trailing != null) ...[
            trailing,
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  // ── Card container ─────────────────────────────────────────────────────────
  static Widget card(
    BuildContext context, {
    required Widget child,
    EdgeInsets? padding,
    VoidCallback? onTap,
    bool hasBorder = true,
  }) {
    final isDark = AppTheme.isDarkMode(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor(context),
          borderRadius: BorderRadius.circular(20),
          border: hasBorder
              ? Border.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.border,
                  width: 1,
                )
              : null,
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: child,
      ),
    );
  }

  // ── Primary button ─────────────────────────────────────────────────────────
  static Widget primaryButton(
    BuildContext context, {
    required String label,
    required VoidCallback? onTap,
    IconData? icon,
    Color? color,
    bool isLoading = false,
    bool fullWidth = true,
  }) {
    final bg = color ?? AppTheme.purpleColor(context);
    Widget content = isLoading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
        : Row(
            mainAxisSize: fullWidth ? MainAxisSize.min : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: Colors.white),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          );

    Widget btn = GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 50,
        width: fullWidth ? double.infinity : null,
        padding: fullWidth ? null : const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: onTap == null ? bg.withValues(alpha: 0.5) : bg,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: content,
      ),
    );
    return btn;
  }

  // ── Drag handle ───────────────────────────────────────────────────────────
  static Widget dragHandle(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppTheme.subtextColor(context).withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  // ── Vital stat card ────────────────────────────────────────────────────────
  static Widget vitalCard(
    BuildContext context, {
    required String value,
    required String unit,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textColor(context),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.subtextColor(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.subtextColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────
  static Widget emptyState(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.elevatedSurface(context),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: AppTheme.subtextColor(context)),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textColor(context),
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.subtextColor(context),
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 20),
              action,
            ],
          ],
        ),
      ),
    );
  }
}
