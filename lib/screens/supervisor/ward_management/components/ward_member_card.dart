import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:aquasense/models/user_data.dart';

class WardMemberCard extends StatelessWidget {
  final UserData member;
  final bool hasComplaint;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const WardMemberCard({
    super.key,
    required this.member,
    required this.hasComplaint,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: GestureDetector(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(26),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: hasComplaint ? Colors.orangeAccent.withAlpha(150) : Colors.white.withAlpha(51),
                  width: hasComplaint ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: hasComplaint ? Colors.orangeAccent : Colors.cyan,
                    child: const Icon(Icons.person_outline, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${member.uid.substring(0, 15)}...',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Phone: ${member.phoneNumber ?? 'N/A'}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (hasComplaint) ...[
                    const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 24),
                    const SizedBox(width: 12),
                  ],
                  const Icon(Icons.arrow_forward_ios, color: Colors.white30, size: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}