import 'package:flutter/material.dart';
import '../utils/theme.dart';

class AvatarWidget extends StatelessWidget {
  final String? avatarUrl;
  final String? name;
  final String? role;
  final double radius;
  final VoidCallback? onTap;
  final bool isEditable;

  const AvatarWidget({
    super.key,
    this.avatarUrl,
    this.name,
    this.role,
    this.radius = 24,
    this.onTap,
    this.isEditable = false,
  });

  @override
  Widget build(BuildContext context) {
    final roleColor = AppTheme.getRoleColor(role);
    final initials = _getInitials(name);

    Widget avatarContent;

    if (avatarUrl != null && avatarUrl!.trim().isNotEmpty) {
      avatarContent = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.network(
          avatarUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _fallbackWidget(roleColor, initials),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: radius * 2,
              height: radius * 2,
              color: roleColor.withValues(alpha: 0.1),
              child: Center(
                child: SizedBox(
                  width: radius * 0.8,
                  height: radius * 0.8,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: roleColor,
                  ),
                ),
              ),
            );
          },
        ),
      );
    } else {
      avatarContent = _fallbackWidget(roleColor, initials);
    }

    final avatarWithBorder = Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: avatarContent,
    );

    if (isEditable || onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            avatarWithBorder,
            if (isEditable)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt,
                  size: 14,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      );
    }

    return avatarWithBorder;
  }

  Widget _fallbackWidget(Color roleColor, String initials) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: roleColor.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: roleColor,
            fontWeight: FontWeight.w700,
            fontSize: radius * 0.75,
          ),
        ),
      ),
    );
  }

  String _getInitials(String? fullName) {
    if (fullName == null || fullName.trim().isEmpty) return '?';
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return fullName.substring(0, 1).toUpperCase();
  }
}
