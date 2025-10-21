import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class HomeHeader extends StatelessWidget {
  final String userName;
  final VoidCallback onNotificationTap;

  const HomeHeader({
    super.key,
    required this.userName,
    required this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 40, bottom: 10), // Increased top padding for status bar
      sliver: SliverToBoxAdapter(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // --- MODIFIED: Wrapped username in a styled container ---
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(20),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 22, // Reduced font size
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(width: 16), // Added spacing
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 30),
              onPressed: onNotificationTap,
            ),
          ],
        ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.2, curve: Curves.easeOut),
      ),
    );
  }
}