import 'package:flutter/material.dart';
import 'package:moring/utils/app_icon.dart'; // AppIcons 클래스 임포트
import 'package:moring/utils/bottom_nav_bar.dart'; // CustomBottomNavBar 위젯 임포트
import 'package:moring/utils/app_theme.dart'; // CustomBottomNavBar 위젯 임포트
import 'package:moring/utils/custom_app_bar.dart'; // CustomBottomNavBar 위젯 임포트
import 'package:moring/models/consumable.dart'; // Consumable 모델 임포트 (수정: utils/ -> models/ 로 경로 변경)
import 'package:moring/widgets/car_360_viewer.dart'; // Car360Viewer 위젯 임포트
import 'package:kakao_flutter_sdk_common/kakao_flutter_sdk_common.dart';

import 'screens/login.dart';
import 'screens/map.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔑 카카오 SDK 초기화 (반드시 runApp 이전에)
  KakaoSdk.init(
    nativeAppKey: 'b0c6ed29bed9644abb543aac61d3e0d6',
    javaScriptAppKey: 'e9de537a4f886944859b124acbc8f5e4',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Moring App',
      // 다크 모드 테마 설정
      theme: AppTheme,
      home: const HomePage(),

      // ↓ 로그인 화면을 첫 화면으로 지정
      initialRoute: '/login',
      routes: {
        '/login': (c) => const LoginPage(),
        '/home':  (c) => const HomePage(), // 또는 MapScreen()
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0; // 하단 네비게이션 바 선택 인덱스

  // 예시 소모품 데이터 (실제로는 서버나 로컬 저장소에서 불러올 것입니다)
  late List<Consumable> consumables;

  // 현재 선택된 차량의 360도 이미지 경로 리스트
  List<String> _currentCarImagePaths = [];
  String _selectedCar = 'xm3'; // 현재 선택된 차량 (초기값)

  // 사용 가능한 차량 목록에 '재규어' 추가
  final List<String> _availableCars = ['xm3', '그렌저', '재규어'];


  @override
  void initState() {
    super.initState();
    // 초기 소모품 데이터 설정
    consumables = [
      Consumable(
        icon: AppIcons.engineOil,
        title: 'Engine Oil',
        lastReplacedDate: DateTime(2025, 5, 15),
        replacementCycleMonths: 8,
      ),
      Consumable(
        icon: AppIcons.engineOil,
        title: 'Oil Filter',
        lastReplacedDate: DateTime(2025, 3, 1),
        replacementCycleMonths: 12,
      ),
      Consumable(
        icon: AppIcons.airFilter,
        title: 'Air Filter',
        lastReplacedDate: DateTime(2025, 1, 10),
        replacementCycleMonths: 8,
      ),
      // 필요한 다른 소모품들을 여기에 추가합니다.
    ];

    // 초기 차량 이미지 경로 설정 (예시: xm3 이미지 사용)
    _setCarImages(_selectedCar); // 초기에는 'xm3' 차량의 이미지를 로드
  }

  // 차량 이미지를 동적으로 설정하는 함수
  void _setCarImages(String carName) {
    setState(() {
      _selectedCar = carName; // 선택된 차량 업데이트
      int numImages;
      String basePath;

      switch (carName) {
        case 'xm3':
          numImages = 36; // XM3 36장으로 업데이트
          basePath = 'assets/xm3/xm3_'; // 파일명 규칙: xm3_1.png 부터 시작
          break;
        case '그렌저':
          numImages = 36; // 그렌저 36장으로 업데이트
          basePath = 'assets/그렌저/'; // 파일명 규칙: 1.png 부터 시작
          break;
        case '재규어':
          numImages = 30; // 재규어 30장으로 설정
          basePath = 'assets/재규어/'; // 파일명 규칙: 재규어_1.png 부터 시작한다고 가정 (실제 파일명 확인 필요)
          break;
        default:
          numImages = 0; // 알 수 없는 차량일 경우
          basePath = '';
          break;
      }

      _currentCarImagePaths = List.generate(
        numImages,
            (index) {
          // 파일명 규칙에 따라 index + 1 사용. 필요시 padLeft(2, '0') 추가 고려
          // 예를 들어, '재규어_01.png' 형태라면 'basePath${(index + 1).toString().padLeft(2, '0')}.png' 로 변경
          return '$basePath${index + 1}.png';
        },
      );
    });
  }


  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // 공통 컴포넌트 위젯 클릭 시 페이지 전환 로직 구현
    // Navigator를 사용하여 다른 화면으로 이동합니다.
    // 현재는 인덱스만 변경하지만, 실제 앱에서는 아래와 같이 Navigator.push 또는 Navigator.pushReplacement를 사용합니다.
    // 예:
    // if (index == 0) {
    //   // Home 화면 (현재 화면이므로 특별한 동작 없음)
    // } else if (index == 1) {
    //   Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => NavigationPage()));
    // } else if (index == 2) {
    //   Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => DrivingLogPage()));
    // } else if (index == 3) {
    //   Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MorePage()));
    // }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 여기를 CustomAppBar로 교체해야 합니다.
      appBar: CustomAppBar(
        title: 'Moring',
        onBackButtonPressed: () {
          // 메인 페이지의 뒤로가기 버튼 동작 (예시: 앱 종료 또는 이전 화면이 없다면 null)
          Navigator.pop(context);
        },
        showCarDropdown: true, // 메인 페이지에서는 차량 드롭다운 표시
        availableCars: _availableCars,
        selectedCar: _selectedCar,
        onCarChanged: (newValue) {
          if (newValue != null) {
            _setCarImages(newValue); // HomePage의 차량 변경 로직 호출
          }
        },
        onNotificationPressed: () {
          // 알림 버튼 액션
          print('알림 버튼 클릭!');
          // Navigator.push(context, MaterialPageRoute(builder: (context) => NotificationPage()));
        },
      ),
      body: SingleChildScrollView( // 내용이 화면을 넘어갈 경우 스크roll 가능하도록
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. 자동차 이미지 및 정보 섹션 (Car360Viewer 사용)
              Container(
                height: 250, // Car360Viewer의 높이 설정
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: Colors.grey[900], // 배경색을 Dark Theme에 맞게
                ),
                child: ClipRRect( // 테두리 둥글게 자르기
                  borderRadius: BorderRadius.circular(15),
                  child: Car360Viewer(
                    imagePaths: _currentCarImagePaths,
                    sensitivity: 10.0, // 이 값을 조절하여 드래그 민감도를 변경할 수 있습니다.
                    width: double.infinity,
                    height: 250,
                  ),
                ),
              ),
              const SizedBox(height: 20),


              // 2. 소모품 현황 섹션
              Text(
                '소모품 현황',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith( // 텍스트 테마 적용
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),

              // 소모품 현황 카드 (동적 생성)
              ...consumables.map((consumable) {
                // 날짜 포맷팅 (예: 2025-07-28)
                final nextReplacementDate = consumable.getNextReplacementDate();
                final formattedDate = '${nextReplacementDate.year}-${nextReplacementDate.month.toString().padLeft(2, '0')}-${nextReplacementDate.day.toString().padLeft(2, '0')}';

                return Column(
                  children: [
                    _buildConsumableStatusCard(
                      context: context,
                      icon: consumable.icon,
                      title: consumable.title,
                      date: '다음 교체: $formattedDate', // 다음 교체일 정보 표시
                      progress: consumable.getRemainingPercentage(), // 계산된 퍼센티지 전달
                    ),
                    const SizedBox(height: 10),
                  ],
                );
              }).toList(),


              const SizedBox(height: 20),

              // 3. 주행 기록 섹션 (Today, Yesterday 등)
              _buildDrivingLogSection(
                context: context,
                title: 'Today',
                logs: [
                  {'distance': '15.2 mi', 'time': '12:30 PM - 1:00 PM'},
                ],
              ),
              const SizedBox(height: 20),
              _buildDrivingLogSection(
                context: context,
                title: 'Yesterday',
                logs: [
                  {'distance': '22.5 mi', 'time': '9:00 AM - 9:45 AM'},
                  {'distance': '5.0 mi', 'time': '5:30 PM - 5:45 PM'},
                ],
              ),
              const SizedBox(height: 20),
              // 더 많은 날짜별 기록 섹션 추가 가능
            ],
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar( // 분리된 CustomBottomNavBar 위젯 사용
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped, // 페이지 전환 로직과 연결
      ),
    );
  }

  // 소모품 현황 카드를 생성하는 위젯
  Widget _buildConsumableStatusCard({
    required BuildContext context,
    required Icon icon,
    required String title,
    required String date,
    required double progress, // 0.0 ~ 1.0
  }) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
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
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 100, // 프로그레스 바 너비 고정
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[700],
                valueColor: AlwaysStoppedAnimation<Color>(
                  // 퍼센티지에 따른 색상 변경 (0.7 이상: 초록, 0.3~0.7: 주황, 0.3 미만: 빨강)
                  progress > 0.7 ? Colors.greenAccent : (progress > 0.3 ? Colors.amberAccent : Colors.redAccent),
                ),
                minHeight: 5,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 주행 기록 섹션을 생성하는 위젯 (Today, Yesterday 등)
  Widget _buildDrivingLogSection({
    required BuildContext context,
    required String title,
    required List<Map<String, String>> logs,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Column(
            children: logs.map((log) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: ListTile(
                  leading: AppIcons.loccation, // 위치 아이콘
                  title: Text(
                    log['distance']!,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                  ),
                  subtitle: Text(
                    log['time']!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                  onTap: () {
                    // TODO: 기록 항목 클릭 시 상세 보기 등 액션 구현
                    // 예를 들어, Navigator.push(context, MaterialPageRoute(builder: (context) => LogDetailPage(logData: log)));
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}