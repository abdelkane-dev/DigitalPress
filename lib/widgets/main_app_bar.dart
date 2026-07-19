import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../core/services/auth_service.dart';
import '../screens/notifications/notifications_screen.dart';
import '../widgets/notification_bell_button.dart';

class MainAppBar extends ConsumerWidget {
  final String title;
  final bool showLogo;
  final Widget? extraAction;
  final Widget? titleBadge;

  const MainAppBar({
    super.key,
    required this.title,
    this.showLogo = false,
    this.extraAction,
    this.titleBadge,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverAppBar(
      toolbarHeight: 76.0,
      expandedHeight: 76.0,
      floating: true,
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFF0A2647),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showLogo) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/app_icon.png',
                width: 36,
                height: 36,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: -0.5,
                ),
              ),
              if (titleBadge != null) ...[
                const SizedBox(width: 8),
                titleBadge!,
              ],
            ],
          ),
        ],
      ),
      actions: [
        if (extraAction != null) extraAction!,
        Container(
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(20),
            shape: BoxShape.circle,
          ),
          child: NotificationBellButton(
            color: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              );
            },
          ),
        ),
        Consumer(
          builder: (context, ref, child) {
            final userAsync = ref.watch(authStateProvider);
            final user = userAsync.valueOrNull;

            ImageProvider? imageProvider;
            if (user?.photoUrl != null && user!.photoUrl!.isNotEmpty) {
              imageProvider = user.photoUrl!.startsWith('http')
                  ? NetworkImage(user.photoUrl!) as ImageProvider
                  : NetworkImage(user.photoUrl!);
            }

            return GestureDetector(
              onTap: () {
                context.push('/profile');
              },
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  image: imageProvider != null
                      ? DecorationImage(
                          image: imageProvider,
                          fit: BoxFit.cover,
                        )
                      : null,
                  color: const Color(0xFF2C74B3),
                ),
                child: imageProvider == null
                    ? const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 24,
                      )
                    : null,
              ),
            );
          },
        ),
      ],
    );
  }
}
