import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moring/models/unread_notification.dart';
import 'package:moring/providers/notification_api_provider.dart';
import 'package:moring/providers/car_provider.dart';
import '../../widgets/sliding_notification_card.dart';

class NotificationLogPage extends ConsumerStatefulWidget {
  const NotificationLogPage({Key? key}) : super(key: key);

  @override
  ConsumerState<NotificationLogPage> createState() => _NotificationLogPageState();
}

class _NotificationLogPageState extends ConsumerState<NotificationLogPage> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final ScrollController _scrollCtrl = ScrollController();
  final List<UnreadNotification> _notifications = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 0;
  static const int _size = 10;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPage());
  }

  Future<void> _loadPage() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    final vin = ref.read(currentVinProvider);
    if (vin == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final api = ref.read(notificationApiProvider);
      final fetched = await api.fetchUnreadNotifications(vin: vin);
      final insertIndex = _notifications.length;
      _notifications.addAll(fetched);
      for (int i = 0; i < fetched.length; i++) {
        _listKey.currentState?.insertItem(insertIndex + i, duration: const Duration(milliseconds: 300));
      }
      _hasMore = fetched.length == _size;
      if (_hasMore && fetched.isNotEmpty) _page++;
    } catch (e) {
      debugPrint('🔔 loadPage error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _removeAt(int index) {
    final removed = _notifications[index];
    _listKey.currentState?.removeItem(
      index,
          (context, animation) => SlideTransition(
        position: Tween<Offset>(begin: Offset.zero, end: const Offset(1, 0))
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeIn)),
        child: SlidingNotificationCard(
          key: ValueKey(removed.id),
          notification: removed,
          onMarkedRead: () {},
        ),
      ),
      duration: const Duration(milliseconds: 300),
    );

    _notifications.removeAt(index);
    ref.read(unreadCountProvider.notifier).state--;
    setState(() {});
  }

  Future<void> _markAllRead() async {
    final vin = ref.read(currentVinProvider);
    if (vin == null) return;
    final api = ref.read(notificationApiProvider);
    await api.fetchReadAllNotification(vin: vin);
    ref.read(unreadCountProvider.notifier).state = 0;

    for (int i = _notifications.length - 1; i >= 0; i--) {
      _removeAt(i);
    }
    _hasMore = false;
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('알림 로그', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_notifications.isNotEmpty)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('전체 확인', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _buildAnimatedList(),
    );
  }

  Widget _buildAnimatedList() {
    if (_isLoading && _notifications.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_isLoading && _notifications.isEmpty) {
      return const Center(
        child: Text('알림이 없습니다.', style: TextStyle(color: Colors.white70, fontSize: 16)),
      );
    }

    return AnimatedList(
      key: _listKey,
      controller: _scrollCtrl,
      initialItemCount: _notifications.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (ctx, idx, anim) {
        if (idx >= _notifications.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final n = _notifications[idx];
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: SlidingNotificationCard(
            key: ValueKey(n.id),
            notification: n,
            onMarkedRead: () {
              final removeIndex = _notifications.indexWhere((e) => e.id == n.id);
              if (removeIndex >= 0) _removeAt(removeIndex);
            },
          ),
        );
      },
    );
  }
}
