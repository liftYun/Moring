import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moring/models/unread_notification.dart';
import 'package:moring/providers/notification_api_provider.dart';
import 'package:moring/utils/app_icon.dart';

class SlidingNotificationCard extends ConsumerStatefulWidget {
  final UnreadNotification notification;
  final VoidCallback onMarkedRead;

  const SlidingNotificationCard({
    Key? key,
    required this.notification,
    required this.onMarkedRead,
  }) : super(key: key);

  @override
  _SlidingNotificationCardState createState() => _SlidingNotificationCardState();
}

class _SlidingNotificationCardState extends ConsumerState<SlidingNotificationCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnim = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(1.0, 0.0),  // 오른쪽으로 밀어내기
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onMarkedRead();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notification;
    final api = ref.read(notificationApiProvider);

    Widget icon;
    String titleText;
    switch (n.notificationDetail) {
      case 'DISTRACTION_ALERT':
        icon = AppIcons.distractionAlert;
        titleText = '운전 집중 필요';
        break;
      case 'FRONT_ALERT':
        icon = AppIcons.frontAlert;
        titleText = '전방 주시 필요';
        break;
      case 'INSPECTION_ALERT':
        icon = AppIcons.inspectionAlert;
        titleText = '정기 점검 기간';
        break;
      case 'OXYGEN_ALERT':
        icon = AppIcons.oxygenAlert;
        titleText = '산소 부족 경고';
        break;
      case 'PART_ALERT':
        icon = AppIcons.partAlert;
        titleText = '부품 교환 권장';
        break;
      default:
        icon = AppIcons.notifications;
        titleText = '알림';
    }

         return SlideTransition(
       position: _slideAnim,
       child: Dismissible(
         key: ValueKey(n.id),
         direction: DismissDirection.startToEnd, // 왼쪽에서 오른쪽으로 슬라이드
         background: Container(
           margin: const EdgeInsets.only(bottom: 12),
           decoration: BoxDecoration(
             color: Colors.red,
             borderRadius: BorderRadius.circular(10),
           ),
           alignment: Alignment.centerLeft,
           padding: const EdgeInsets.only(left: 20),
           child: const Icon(
             Icons.delete,
             color: Colors.white,
             size: 30,
           ),
         ),
         confirmDismiss: (direction) async {
           // 서버에 읽음 처리 요청
           final success = await api.fetchReadNotification(id: n.id);
           if (success) {
             // 콜백 호출하여 부모에게 삭제 알림
             widget.onMarkedRead();
           }
           return success;
         },
         child: Card(
           elevation: 0,
           margin: const EdgeInsets.only(bottom: 12),
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
           child: Padding(
             padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
             child: Row(
               children: [
                 icon,
                 const SizedBox(width: 15),
                 Expanded(
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(
                         // 제목
                         titleText,
                         style: Theme.of(context).textTheme.titleMedium?.copyWith(
                           fontWeight: FontWeight.bold,
                           color: Colors.white,
                         ),
                       ),
                       const SizedBox(height: 4),
                       // 본문
                       Text(
                         n.message, 
                         style: Theme.of(context).textTheme.bodySmall?.copyWith(
                           color: Colors.white70,
                         ),
                       ),
                       const SizedBox(height: 4),
                       // 시간
                       Text(
                         TimeOfDay.fromDateTime(n.createdAt.toLocal()).format(context),
                         style: Theme.of(context).textTheme.bodySmall?.copyWith(
                           color: Colors.grey[400],
                         ),
                       ),
                     ],
                   ),
                 ),
               ],
             ),
           ),
         ),
       ),
     );
  }
}
