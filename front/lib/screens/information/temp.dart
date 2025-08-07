// /// 혹시 알림패널 애니메이션 적용 에러를 위한 예비 템플릿
// import 'dart:ui';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:moring/models/unread_notification.dart';
// import 'package:moring/providers/car_provider.dart';
// import 'package:moring/providers/notification_api_provider.dart';
// import 'package:moring/utils/app_icon.dart';
//
//
// class NotificationPanel extends ConsumerStatefulWidget {
//   const NotificationPanel({Key? key}) : super(key: key);
//
//   @override
//   ConsumerState<NotificationPanel> createState() =>
//       _NotificationPanelState();
// }
//
// class _NotificationPanelState extends ConsumerState<NotificationPanel> {
//   final ScrollController _scrollCtrl = ScrollController();
//   List<UnreadNotification> _notifications = [];
//   bool _isLoading = false;
//   bool _hasMore = true;
//   int _page = 0;
//   final int _size = 10;
//
//   @override
//   void initState() {
//     super.initState();
//     // 첫 페이지 로드
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _loadPage();
//     });
//     // 무한 스크롤
//     _scrollCtrl.addListener(() {
//       if (_scrollCtrl.position.pixels >=
//           _scrollCtrl.position.maxScrollExtent - 100) {
//         _loadPage();
//       }
//     });
//   }
//
//   Future<void> _loadPage() async {
//     if (_isLoading || !_hasMore) return;
//     setState(() => _isLoading = true);
//
//     final vin = ref.read(currentVinProvider);
//     if (vin == null) {
//       setState(() => _isLoading = false);
//       return;
//     }
//
//     try {
//       final api = ref.read(notificationApiProvider);
//       final fetched = await api.fetchUnreadNotifications(
//         vin: vin,
//         page: _page,
//         size: _size,
//       );
//       setState(() {
//         _notifications.addAll(fetched);
//         _hasMore = fetched.length == _size;
//         if (_hasMore) _page++;
//       });
//     } catch (e) {
//       debugPrint('🔔 loadPage error: $e');
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }
//
//   @override
//   void dispose() {
//     _scrollCtrl.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final itemHeight = 100.0;
//     final maxFactor = 0.7;
//     final minFactor = 0.3;
//     final contentHeight = (_notifications.length * itemHeight + 100) / MediaQuery.of(context).size.height;
//     final heightFactor = contentHeight.clamp(minFactor, maxFactor);
//     return Material(
//       type: MaterialType.transparency,
//       child: Stack(
//         children: [
//           Positioned.fill(
//             child: GestureDetector(
//               behavior: HitTestBehavior.opaque,
//               onTap: () => Navigator.of(context).pop(),
//               child: const SizedBox(),
//             ),
//           ),
//
//           // 1) 백그라운드 블러
//           BackdropFilter(
//             filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
//             child: IgnorePointer(
//               child: Container(color: Colors.black.withOpacity(0.3)),
//             ),
//           ),
//
//           // 2) SafeArea 아래에 패널
//           SafeArea(
//             bottom: false,
//             child: Align(
//               alignment: Alignment.topCenter,
//               child: FractionallySizedBox(
//                 heightFactor: heightFactor,
//                 child: GestureDetector(
//                   // 이 GestureDetector로 패널 내부 터치를 흡수
//                   behavior: HitTestBehavior.translucent,
//                   onTap: () {},
//                   child: Container(
//                     margin: const EdgeInsets.only(top: 16),
//                     height: MediaQuery.of(context).size.height * 0.8,
//                     decoration: BoxDecoration(
//                       color: Colors.white.withOpacity(0.15),
//                       borderRadius: const BorderRadius.vertical(
//                         bottom: Radius.circular(16),
//                       ),
//                     ),
//                     child: _buildList(),),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildList() {
//     if (_isLoading && _notifications.isEmpty) {
//       return const Center(child: CircularProgressIndicator());
//     }
//
//     return ListView.builder(
//       controller: _scrollCtrl,
//       padding: const EdgeInsets.symmetric(vertical: 8),
//       itemCount: _notifications.length + (_hasMore ? 1 : 0),
//       itemBuilder: (context, idx) {
//         if (idx >= _notifications.length) {
//           return const Padding(
//             padding: EdgeInsets.symmetric(vertical: 16),
//             child: Center(child: CircularProgressIndicator()),
//           );
//         }
//         final n = _notifications[idx];
//         return _buildNotificationCard(n);
//       },
//     );
//   }
//
//   Widget _buildNotificationCard(UnreadNotification n) {
//     final api = ref.read(notificationApiProvider);
//     Widget icon;
//     String titleText;
//     switch (n.notificationDetail) {
//       case 'DISTRACTION_ALERT':
//         icon = AppIcons.distractionAlert;
//         titleText = '운전 집중 필요';
//         break;
//       case 'FRONT_ALERT':
//         icon = AppIcons.frontAlert;
//         titleText = '전방 주시 필요';
//         break;
//       case 'INSPECTION_ALERT':
//         icon = AppIcons.inspectionAlert;
//         titleText = '정기 점검 기간';
//         break;
//       case 'OXYGEN_ALERT':
//         icon = AppIcons.oxygenAlert;
//         titleText = '산소 부족 경고';
//         break;
//       case 'PART_ALERT':
//         icon = AppIcons.partAlert;
//         titleText = '부품 교환 권장';
//         break;
//       default:
//         icon = AppIcons.notifications;
//         titleText = '알림';
//     }
//
//     final timeText = TimeOfDay.fromDateTime(n.createdAt.toLocal()).format(
//         context);
//
//     return Card(
//       margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       elevation: 2,
//       color: Colors.black38,
//       child: InkWell(
//         borderRadius: BorderRadius.circular(12),
//         // onTap: () => debugPrint('🔔 tapped id=${n.id}'),
//         onTap: () async {
//           try {
//             final bool success = await api.fetchReadNotification(id: n.id);
//             if (success) {
//               setState(() {
//                 _notifications.removeWhere((e) => e.id == n.id);
//                 if (_notifications.isEmpty) _hasMore = false;
//               });
//             }
//           } catch (e) {
//             debugPrint('🔔 mark read error: $e');
//           }
//         },
//         child: Padding(
//           padding: const EdgeInsets.all(12),
//           child: Row(
//             crossAxisAlignment: CrossAxisAlignment.center,
//             children: [
//               icon,
//               const SizedBox(width: 12),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     // 3) 제목 (bold)
//                     Text(
//                       titleText,
//                       style: const TextStyle(
//                         fontSize: 14,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.white,
//                       ),
//                     ),
//                     const SizedBox(height: 4),
//                     // 4) 본문
//                     Text(
//                       n.message,
//                       style: const TextStyle(
//                         fontSize: 12,
//                         color: Colors.white70,
//                       ),
//                     ),
//                     const SizedBox(height: 6),
//                     // 5) 시간
//                     Text(
//                       timeText,
//                       style: TextStyle(
//                         fontSize: 8,
//                         color: Colors.grey[400],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
// /// 애니메이션 그나마 부드러웠던버젼
// import 'dart:ui';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:moring/models/unread_notification.dart';
// import 'package:moring/providers/notification_api_provider.dart';
// import 'package:moring/providers/car_provider.dart';
//
// import '../../widgets/sliding_notification_card.dart';
//
// class NotificationPanel extends ConsumerStatefulWidget {
//   const NotificationPanel({Key? key}) : super(key: key);
//
//   @override
//   ConsumerState<NotificationPanel> createState() => _NotificationPanelState();
// }
//
// class _NotificationPanelState extends ConsumerState<NotificationPanel>
//     with SingleTickerProviderStateMixin {
//   final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
//   final ScrollController _scrollCtrl = ScrollController();
//   final List<UnreadNotification> _notifications = [];
//   bool _isLoading = false;
//   bool _hasMore = true;
//   int _page = 0;
//   static const int _size = 10;
//
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) => _loadPage());
//     _scrollCtrl.addListener(() {
//       if (_scrollCtrl.position.pixels >=
//           _scrollCtrl.position.maxScrollExtent - 100 &&
//           !_isLoading && _hasMore) {
//         _loadPage();
//       }
//     });
//   }
//
//   Future<void> _loadPage() async {
//     if (_isLoading || !_hasMore) return;
//     setState(() => _isLoading = true);
//
//     final vin = ref.read(currentVinProvider);
//     if (vin == null) {
//       setState(() => _isLoading = false);
//       return;
//     }
//
//     try {
//       final api = ref.read(notificationApiProvider);
//       final fetched = await api.fetchUnreadNotifications(
//         vin: vin,
//         page: _page,
//         size: _size,
//       );
//       final insertIndex = _notifications.length;
//       setState(() {
//         _notifications.addAll(fetched);
//       });
//       for (int i = 0; i < fetched.length; i++) {
//         _listKey.currentState?.insertItem(
//           insertIndex + i,
//           duration: const Duration(milliseconds: 300),
//         );
//       }
//       _hasMore = fetched.length == _size;
//       if (_hasMore) _page++;
//     } catch (e) {
//       debugPrint('🔔 loadPage error: $e');
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }
//
//   @override
//   void dispose() {
//     _scrollCtrl.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final screenH = MediaQuery.of(context).size.height;
//     const itemH = 100.0;
//     final rawFactor = (_notifications.length * itemH + 100) / screenH;
//     final heightFactor = rawFactor.clamp(0.3, 0.7) as double;
//
//     return Material(
//       type: MaterialType.transparency,
//       child: Stack(
//         children: [
//           Positioned.fill(
//             child: GestureDetector(
//               behavior: HitTestBehavior.opaque,
//               onTap: () => Navigator.of(context).pop(),
//             ),
//           ),
//           BackdropFilter(
//             filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
//             child: IgnorePointer(
//               child: Container(color: Colors.black.withOpacity(0.3)),
//             ),
//           ),
//           SafeArea(
//             bottom: false,
//             child: Align(
//               alignment: Alignment.topCenter,
//               child: FractionallySizedBox(
//                 heightFactor: heightFactor,
//                 child: Container(
//                   margin: const EdgeInsets.only(top: 16),
//                   decoration: BoxDecoration(
//                     color: Colors.white.withOpacity(0.15),
//                     borderRadius: const BorderRadius.vertical(
//                         bottom: Radius.circular(16)),
//                   ),
//                   child: _buildAnimatedList(),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildAnimatedList() {
//     if (_isLoading && _notifications.isEmpty) {
//       return const Center(child: CircularProgressIndicator());
//     }
//
//     return AnimatedList(
//       key: _listKey,
//       controller: _scrollCtrl,
//       initialItemCount: _notifications.length + (_hasMore ? 1 : 0),
//       padding: const EdgeInsets.symmetric(vertical: 8),
//       itemBuilder: (ctx, idx, anim) {
//         // 로딩 인디케이터
//         if (idx >= _notifications.length) {
//           return const Padding(
//             padding: EdgeInsets.symmetric(vertical: 16),
//             child: Center(child: CircularProgressIndicator()),
//           );
//         }
//         final n = _notifications[idx];
//         return SlideTransition(
//           position: anim.drive(
//             Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
//                 .chain(CurveTween(curve: Curves.easeOut)),
//           ),
//           child: SlidingNotificationCard(
//             key: ValueKey(n.id),
//             notification: n,
//             onMarkedRead: () {
//               final removeIndex = _notifications.indexWhere((e) => e.id == n.id);
//               if (removeIndex >= 0) {
//                 setState(() {
//                   final removed = _notifications.removeAt(removeIndex);
//                   _listKey.currentState?.removeItem(
//                     removeIndex,
//                         (ctx, anim) => SlideTransition(
//                       position: anim.drive(
//                         Tween<Offset>(
//                             begin: Offset.zero, end: const Offset(1, 0))
//                             .chain(CurveTween(curve: Curves.easeIn)),
//                       ),
//                       child: SlidingNotificationCard(
//                         notification: removed,
//                         onMarkedRead: () {},
//                       ),
//                     ),
//                     duration: const Duration(milliseconds: 300),
//                   );
//                 });
//               }
//             },
//           ),
//         );
//       },
//     );
//   }
// }