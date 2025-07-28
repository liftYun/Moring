import 'package:flutter/material.dart';
import 'package:moring/utils/app_icon.dart'; // AppIcons 클래스 임포트
import 'package:moring/utils/bottom_nav_bar.dart'; // CustomBottomNavBar 위젯 임포트
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
      theme: ThemeData(
        brightness: Brightness.dark, // 전체적으로 다크 모드
        primarySwatch: Colors.teal, // 주요 색상
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black, // 앱바 배경색
          foregroundColor: Colors.white, // 앱바 아이콘 및 텍스트 색상
        ),
        scaffoldBackgroundColor: Colors.black, // Scaffold 전체 배경색
        cardColor: Colors.grey[900], // 카드 배경색 (이미지에서 보이는 진한 회색)
        // 텍스트 테마 설정 (Flutter의 dp 단위 사용, rem 개념은 Flutter에 직접 적용되지 않음)
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: Colors.white, fontSize: 57),
          displayMedium: TextStyle(color: Colors.white, fontSize: 45),
          displaySmall: TextStyle(color: Colors.white, fontSize: 36),
          headlineLarge: TextStyle(color: Colors.white, fontSize: 32),
          headlineMedium: TextStyle(color: Colors.white, fontSize: 28),
          headlineSmall: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), // '소모품 현황'
          titleLarge: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold), // 'Today', 'Yesterday' 타이틀
          titleMedium: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), // 소모품 제목, 주행 거리
          titleSmall: TextStyle(color: Colors.white, fontSize: 16),
          bodyLarge: TextStyle(color: Colors.white, fontSize: 16),
          bodyMedium: TextStyle(color: Colors.white70, fontSize: 14),
          bodySmall: TextStyle(color: Colors.grey, fontSize: 12), // 날짜, 시간 정보
          labelLarge: TextStyle(color: Colors.white, fontSize: 14),
          labelMedium: TextStyle(color: Colors.white, fontSize: 12),
          labelSmall: TextStyle(color: Colors.white, fontSize: 11),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.grey[900], // 하단 바 배경색
          selectedItemColor: Colors.tealAccent, // 선택된 아이템 색상
          unselectedItemColor: Colors.grey, // 선택되지 않은 아이템 색상
          showUnselectedLabels: true, // 선택되지 않은 라벨도 항상 표시
          type: BottomNavigationBarType.fixed, // 아이템이 4개 이상일 때도 고정
        ),
      ),
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
    // 메인 페이지는 모바일과 태블릿 규격에 맞게 UI 깨짐 현상이 없어야 한다.
    // Scaffold, SingleChildScrollView, Expanded 등 Flutter의 반응형 위젯을 활용하여 구현됩니다.
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context); // 이전 화면으로 돌아가는 예시
          },
        ),
        title: Text('Moring', style: Theme.of(context).textTheme.titleLarge),
        centerTitle: true,
        actions: [
          // 차량 선택 드롭다운 메뉴 추가
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCar,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                dropdownColor: Colors.grey[850], // 드롭다운 배경색
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    _setCarImages(newValue);
                  }
                },
                items: _availableCars.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value.toUpperCase()), // 차량 이름을 대문자로 표시
                  );
                }).toList(),
              ),
            ),
          ),
          IconButton(
            icon: AppIcons.notifications,
            onPressed: () {
              // 알림 버튼 액션
            },
          ),
        ],
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