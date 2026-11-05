import 'package:flutter/material.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';

class UserProfileCard extends StatelessWidget {
  const UserProfileCard({
    super.key,
    required this.name,
    required this.role,
    this.avatarUrl,
    this.email,
    this.onTap,
    this.compact = false,
  });

  final String name;
  final String role;
  final String? avatarUrl;
  final String? email;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cleanUrl = avatarUrl?.trim();
    final hasAvatar = cleanUrl != null && cleanUrl.isNotEmpty;
    final size = compact ? 42.0 : 62.0;

    return Material(
      color: compact ? Colors.transparent : const Color(0xFFF3F6FD),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: EdgeInsets.all(compact ? 8 : 12),
          child: Row(
            children: [
              // Avatar dùng CachedNetworkImage trực tiếp
              ClipOval(
                child: SizedBox(
                  width: size,
                  height: size,
                  child: ColoredBox(
                    color: const Color(0xFFDCE8FF),
                    child: hasAvatar
                        ? CachedNetworkImage(
                            imageUrl: cleanUrl,
                            fit: BoxFit.cover,
                            // Dùng memCache để load thẳng từ RAM, không bị nháy khi mở Drawer
                            memCacheWidth:
                                (size * MediaQuery.of(context).devicePixelRatio)
                                    .round(),
                            placeholder: (context, url) => const SizedBox(),
                            errorWidget: (context, url, error) => const Icon(
                              Icons.person_rounded,
                              color: AppColors.primary,
                            ),
                          )
                        : const Icon(
                            Icons.person_rounded,
                            color: AppColors.primary,
                          ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF172B55),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      role,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                      ),
                    ),
                    if (!compact &&
                        email != null &&
                        email!.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        email!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              if (onTap != null)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: Color(0xFF64748B),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
