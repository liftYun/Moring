import 'package:flutter/material.dart';
import 'package:moring/models/notification.dart';
import 'package:moring/utils/app_icon.dart';
import 'package:moring/utils/custom_app_bar.dart';
import 'package:moring/utils/bottom_nav_bar.dart';
import 'package:moring/models/consumable.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Riverpod import 추가
import 'package:moring/providers/api_client.dart';

import '../../utils/base_scaffold.dart'; // authDio import 추가

class NotificationPage extends ConsumerStatefulWidget {
  const NotificationPage({super.key});

  @override
  ConsumerState<NotificationPage> createState() => _NotificationPageState(); // ConsumerState로 변경
}

class _NotificationPageState extends ConsumerState<NotificationPage> {
  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: '',
      showBack: true,
      onBackButtonPressed: () {
        final nav = Navigator.of(context);
        if (Navigator.of(context).canPop()) {
          nav.pop();
        } else {
          nav.pushNamedAndRemoveUntil('/carselection',(route) => false,);
        }
      },
      body: IndexedStack(
        index: 0,
      ),
      withBottomNav: true,                 // 바텀바를 쓰겠다
    );
  }
}
