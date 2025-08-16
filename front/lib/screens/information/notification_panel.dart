import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moring/models/unread_notification.dart';
import 'package:moring/providers/notification_api_provider.dart';
import 'package:moring/providers/car_provider.dart';

import '../../widgets/sliding_notification_card.dart';

class NotificationPanel extends ConsumerStatefulWidget {
  const NotificationPanel({Key? key}) : super(key: key);

  @override
  ConsumerState<NotificationPanel> createState() => _NotificationPanelState();
}

class _NotificationPanelState extends ConsumerState<NotificationPanel>
    with SingleTickerProviderStateMixin {
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
    // _scrollCtrl.addListener(() {
    //   if (_scrollCtrl.position.pixels >=
    //       _scrollCtrl.position.maxScrollExtent - 100 &&
    //       !_isLoading &&
    //       _hasMore) {
    //     _loadPage();
    //   }
    // });
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
      final fetched = await api.fetchUnreadNotifications(
        vin: vin,
        // page: _page,
        // size: _size,
      );
      final insertIndex = _notifications.length;
      _notifications.addAll(fetched);
      for (int i = 0; i < fetched.length; i++) {
        _listKey.currentState?.insertItem(
          insertIndex + i,
          duration: const Duration(milliseconds: 300),
        );
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
    // 삭제 애니메이션을 위한 원본 데이터 확보
    final removed = _notifications[index];

    // 1) AnimatedList에게 삭제 애니메이션 요청
    _listKey.currentState?.removeItem(
      index,
          (context, animation) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: Offset.zero,
            end: const Offset(1, 0),
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeIn),
          ),
          child: SlidingNotificationCard(
            key: ValueKey(removed.id),
            notification: removed,
            onMarkedRead: () {},
          ),
        );
      },
      duration: const Duration(milliseconds: 300),
    );

    // 2) 실제 데이터에서 제거하고, 높이/버튼 상태 등을 리빌드
    // setState(() {
    //   _notifications.removeAt(index);
    // });
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
    // 뒤에서부터 하나씩 애니메이션 삭제
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
    final screenH = MediaQuery.of(context).size.height;
    const itemH = 100.0;
    final rawFactor = (_notifications.length * itemH + 140) / screenH;
    final heightFactor = rawFactor.clamp(0.3, 0.8);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: IgnorePointer(
              child: Container(color: Colors.black.withOpacity(0.3)),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {},
                child: FractionallySizedBox(
                  heightFactor: heightFactor,
                  child: Container(
                    margin: const EdgeInsets.only(top: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(16)),
                    ),
                    child: Column(
                      children: [
                        Expanded(child: _buildAnimatedList()),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: TextButton(
                              onPressed: _notifications.isEmpty
                                  ? null
                                  : _markAllRead,
                              child: const Text('전체 확인'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedList() {
    if (_isLoading && _notifications.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_isLoading && _notifications.isEmpty) {
      // 로딩 끝났고 알림이 없을 때 메시지 표시
      return const Center(
        child: Text(
          '알림이 없습니다.',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      );
    }

    return AnimatedList(
      key: _listKey,
      controller: _scrollCtrl,
      // 초기 카운트는 내부 상태에서만 사용하므로, 리빌드 시 재설정 불필요
      // initialItemCount: _notifications.length + (_hasMore ? 1 : 0),
      initialItemCount: _notifications.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (ctx, idx, anim) {
        // 로딩 스피너
        if (idx >= _notifications.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final n = _notifications[idx];
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOut),
          ),
          child: SlidingNotificationCard(
            key: ValueKey(n.id),
            notification: n,
            onMarkedRead: () {
              final removeIndex =
              _notifications.indexWhere((e) => e.id == n.id);
              if (removeIndex >= 0) {
                _removeAt(removeIndex);
              }
            },
          ),
        );
      },
    );
  }
}
