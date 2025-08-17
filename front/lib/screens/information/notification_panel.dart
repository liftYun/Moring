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
  final List<Widget> _groupedItems = []; // 날짜별로 그룹화된 아이템들
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 0;
  static const int _size = 10;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPage());
    _scrollCtrl.addListener(() {
      // 더 이상 로드할 알림이 없으면 스크롤 리스너 비활성화
      if (!_hasMore) return;
      
      if (_scrollCtrl.position.pixels >=
          _scrollCtrl.position.maxScrollExtent - 100 &&
          !_isLoading &&
          _hasMore) {
        _loadPage();
      }
    });
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
      final response = await api.fetchUnreadNotifications(
        vin: vin,
        page: _page,
        size: _size,
      );
      
      final fetched = response['notifications'] as List<UnreadNotification>;
      final isLast = response['last'] as bool;
      final isEmpty = response['empty'] as bool;
      final numberOfElements = response['numberOfElements'] as int;
      
      debugPrint('🔔 API Response: last=$isLast, empty=$isEmpty, numberOfElements=$numberOfElements, fetched=${fetched.length}');
      
      final insertIndex = _notifications.length;
      _notifications.addAll(fetched);
      
      // 날짜별로 그룹화하여 아이템 생성
      _updateGroupedItems();
      
      for (int i = 0; i < _groupedItems.length; i++) {
        _listKey.currentState?.insertItem(
          insertIndex + i,
          duration: const Duration(milliseconds: 300),
        );
      }
      
      // 페이지네이션 로직 개선
      if (isEmpty || isLast || numberOfElements == 0) {
        _hasMore = false;
        debugPrint('🔔 No more notifications to load (empty=$isEmpty, last=$isLast, numberOfElements=$numberOfElements)');
      } else {
        _hasMore = true;
        if (fetched.isNotEmpty) _page++;
      }
      
      debugPrint('🔔 Pagination: hasMore=$_hasMore, page=$_page, fetched=${fetched.length}');
    } catch (e) {
      debugPrint('🔔 loadPage error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _updateGroupedItems() {
    _groupedItems.clear();
    
    if (_notifications.isEmpty) return;
    
    // 날짜별로 그룹화
    final Map<String, List<UnreadNotification>> groupedNotifications = {};
    
    for (final notification in _notifications) {
      final dateKey = _getDateKey(notification.createdAt);
      if (!groupedNotifications.containsKey(dateKey)) {
        groupedNotifications[dateKey] = [];
      }
      groupedNotifications[dateKey]!.add(notification);
    }
    
    // 날짜 순으로 정렬 (최신 날짜가 위로)
    final sortedDates = groupedNotifications.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    
    // 각 날짜 그룹에 대해 헤더와 아이템들 생성
    for (final dateKey in sortedDates) {
      final notifications = groupedNotifications[dateKey]!;
      
      // 날짜 헤더 추가
      _groupedItems.add(_buildDateHeader(dateKey));
      
      // 해당 날짜의 알림들을 시간순으로 정렬 (최신이 위로)
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      // 해당 날짜의 알림들 추가
      for (final notification in notifications) {
        _groupedItems.add(
          SlidingNotificationCard(
            key: ValueKey(notification.id),
            notification: notification,
            onMarkedRead: () {
              final removeIndex = _notifications.indexWhere((e) => e.id == notification.id);
              if (removeIndex >= 0) _removeAt(removeIndex);
            },
          ),
        );
      }
    }
  }

  String _getDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final targetDate = DateTime(date.year, date.month, date.day);
    
    if (targetDate == today) {
      return '오늘';
    } else if (targetDate == yesterday) {
      return '어제';
    } else {
      return '${date.year}년 ${date.month}월 ${date.day}일';
    }
  }

  Widget _buildDateHeader(String dateKey) {
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        dateKey,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _removeAt(int index) {
    // 삭제 애니메이션을 위한 원본 데이터 확보
    final removed = _notifications[index];

    // 그룹화된 아이템에서도 제거
    _updateGroupedItems();

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
          child: _groupedItems.isNotEmpty && index < _groupedItems.length 
              ? _groupedItems[index] 
              : SlidingNotificationCard(
                  key: ValueKey(removed.id),
                  notification: removed,
                  onMarkedRead: () {},
                ),
        );
      },
      duration: const Duration(milliseconds: 300),
    );

    // 2) 실제 데이터에서 제거하고, 높이/버튼 상태 등을 리빌드
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
    _updateGroupedItems();
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
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white70,
                              ),
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
      initialItemCount: _groupedItems.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (ctx, idx, anim) {
        // 더 이상 로드할 것이 없으면 빈 공간 표시하지 않음
        if (idx >= _groupedItems.length) {
          return const SizedBox.shrink();
        }
        
        final item = _groupedItems[idx];
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOut),
          ),
          child: item,
        );
      },
    );
  }
}
