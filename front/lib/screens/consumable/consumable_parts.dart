// Path: front/lib/screens/consumable/consumable_parts.dart

import 'package:flutter/material.dart';
import 'package:moring/utils/app_icon.dart'; // AppIcons 클래스를 위해
import 'package:moring/utils/custom_app_bar.dart'; // CustomAppBar 위젯을 위해
import 'package:moring/utils/bottom_nav_bar.dart'; // CustomBottomNavBar 위젯을 위해
import 'package:moring/models/consumable.dart'; // Consumable 모델 임포트


class ConsumablePartsScreen extends StatefulWidget {
  const ConsumablePartsScreen({super.key});

  @override
  State<ConsumablePartsScreen> createState() => _ConsumablePartsScreenState();
}

class _ConsumablePartsScreenState extends State<ConsumablePartsScreen> {
  int _selectedIndex = 0; // 하단 네비게이션 바 선택 인덱스
  late List<Consumable> _consumables; // 소모품 데이터를 담을 리스트

  @override
  void initState() {
    super.initState();
    _initializeConsumables();
  }

  void _initializeConsumables() {
    // 현재 시간을 기준으로 소모품 교체 주기를 시뮬레이션합니다.
    final DateTime now = DateTime.now();

    _consumables = [
      Consumable(
        icon: AppIcons.engineOil,
        title: 'Engine Oil',
        lastReplacedDate: DateTime(now.year, now.month - 1, now.day), // 1개월 전
        replacementCycleMonths: 6, // DB 기준: 6개월
      ),
      Consumable(
        icon: AppIcons.engineOil, // Oil Filter 아이콘은 Engine Oil과 유사
        title: 'Oil Filter',
        lastReplacedDate: DateTime(now.year, now.month - 2, now.day), // 2개월 전
        replacementCycleMonths: 6, // DB에 없으므로 Engine Oil과 유사하게 6개월 가정
      ),
      Consumable(
        icon: AppIcons.airFilter,
        title: 'Air Filter',
        lastReplacedDate: DateTime(now.year, now.month - 5, now.day), // 5개월 전
        replacementCycleMonths: 12, // DB 기준: 12개월
      ),
      Consumable(
        icon: AppIcons.airFilter, // Cabin Filter 아이콘은 Air Filter와 유사
        title: 'Cabin Filter',
        lastReplacedDate: DateTime(now.year - 0, now.month - 7, now.day), // 7개월 전
        replacementCycleMonths: 12, // DB에 없으므로 유사하게 12개월 가정
      ),
      Consumable(
        icon: AppIcons.sparkPlugs,
        title: 'Spark Plugs',
        lastReplacedDate: DateTime(now.year, now.month - 1, now.day - 10), // 1개월 10일 전
        replacementCycleMonths: 24, // DB 기준: 24개월
      ),
      Consumable(
        icon: AppIcons.breakFluid,
        title: 'Brake Fluid',
        lastReplacedDate: DateTime(now.year - 1, now.month - 10, now.day), // 1년 10개월 전 (낮은 진행률)
        replacementCycleMonths: 24, // DB 기준: 24개월
      ),
      Consumable(
        icon: AppIcons.coolant,
        title: 'Coolant',
        lastReplacedDate: DateTime(now.year - 1, now.month - 11, now.day), // 1년 11개월 전 (매우 낮은 진행률)
        replacementCycleMonths: 24, // DB 기준: 24개월
      ),
      Consumable(
        icon: AppIcons.transmissionFluid, // Transmission Fluid 아이콘 (AppIcons에 없음, 임시로 설정)
        title: 'Transmission Fluid',
        lastReplacedDate: DateTime(now.year, now.month, now.day - 5), // 5일 전 (매우 높은 진행률)
        replacementCycleMonths: 36, // DB에 없으므로 긴 주기 가정
      ),
      Consumable(
        icon: AppIcons.loccation, // 임시 타이어 아이콘 (AppIcons에 없음)
        title: 'Tire',
        lastReplacedDate: DateTime(now.year - 2, now.month, now.day), // 2년 전
        replacementCycleMonths: 36, // DB 기준: 36개월
      ),
      Consumable(
        icon: AppIcons.breakFluid, // 임시 브레이크 패드 아이콘 (AppIcons에 없음)
        title: 'Brake Pad',
        lastReplacedDate: DateTime(now.year - 1, now.month - 5, now.day), // 1년 5개월 전
        replacementCycleMonths: 24, // DB 기준: 24개월
      ),
      Consumable(
        icon: AppIcons.engineOil, // 임시 와이퍼 블레이드 아이콘 (AppIcons에 없음)
        title: 'Wiper Blade',
        lastReplacedDate: DateTime(now.year, now.month - 6, now.day), // 6개월 전
        replacementCycleMonths: 12, // DB 기준: 12개월
      ),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // 하단바 탭 시 페이지 전환 로직
    if (index == 0) { // Home 탭 (인덱스 0)
      if (Navigator.canPop(context)) {
        Navigator.pop(context); // 이전 화면(대부분 HomePage/HomeContent)으로 돌아가기
      } else {
        debugPrint('ConsumablePartsScreen이 스택의 최상단입니다. 홈으로 강제 이동...');
      }
    }
    // 다른 탭에 대한 이동 로직은 필요에 따라 추가
  }

  // 각 소모품 상태 카드를 빌드하는 헬퍼 위젯
  Widget _buildConsumableItemCard({
    required BuildContext context,
    required Consumable consumable, // Consumable 객체를 직접 전달
  }) {
    // '마지막 교체일'을 사용합니다.
    final formattedLastReplacedDate = '${consumable.lastReplacedDate.year}-${consumable.lastReplacedDate.month.toString().padLeft(2, '0')}-${consumable.lastReplacedDate.day.toString().padLeft(2, '0')}';
    final progress = consumable.getRemainingPercentage();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12), // 각 카드 아래 간격 추가
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            consumable.icon,
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    consumable.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // '교체일: YYYY-MM-DD' 형식으로 마지막 교체일 표시
                  Text(
                    '$formattedLastReplacedDate',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            // 프로그레스 바와 퍼센트 함께 표시
            Row(
              children: [
                SizedBox(
                  width: 80, // 프로그레스 바의 너비 조정
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey[700],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress > 0.7 ? Colors.greenAccent : (progress > 0.3 ? Colors.amberAccent : Colors.redAccent),
                    ),
                    minHeight: 5,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                const SizedBox(width: 8), // 프로그레스 바와 퍼센트 사이 간격
                Text(
                  '${(progress * 100).toInt()}%', // 퍼센트 표시
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: '소모품', // 이미지에 맞춰 "소모품"으로 타이틀 설정
        onBackButtonPressed: () {
          Navigator.pop(context); // 이전 화면(HomePage)으로 돌아가기
        },
        onNotificationPressed: () {
          debugPrint('소모품 화면 알림 버튼 클릭!');
        },
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // '교체 날짜' 텍스트만 표시하고 날짜는 제거
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          '교체 날짜', // "교체 날짜" 텍스트만 유지
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                        // 날짜 텍스트는 완전히 제거된 상태입니다.
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.sort, color: Colors.white), // 정렬/필터 아이콘
                      onPressed: () {
                        debugPrint('정렬/필터 버튼 클릭!');
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10), // 위젯 간 간격 유지
              // _consumables 리스트에서 동적으로 소모품 항목 빌드
              ..._consumables.map((consumable) {
                return _buildConsumableItemCard(
                  context: context,
                  consumable: consumable,
                );
              }).toList(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }
}