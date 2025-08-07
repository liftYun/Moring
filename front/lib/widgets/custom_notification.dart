// widgets/custom_notification_card.dart
import 'package:flutter/material.dart';

class CustomNotificationCard extends StatelessWidget {
  final String title;
  final String body;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const CustomNotificationCard({
    super.key,
    required this.title,
    required this.body,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              // 알림 아이콘
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.notifications,
                  color: Colors.blue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // 알림 내용
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // 닫기 버튼
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(
                  Icons.close,
                  color: Colors.grey,
                  size: 18,
                ),
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}