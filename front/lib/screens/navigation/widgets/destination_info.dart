import 'package:flutter/material.dart';

class DestinationInfo extends StatelessWidget {
  final String destination;
  final String estimatedTime;
  final String estimatedDistance;
  final String trafficInfo;
  final VoidCallback onClear;
  final bool isDriving;

  const DestinationInfo({
    super.key,
    required this.destination,
    required this.estimatedTime,
    required this.estimatedDistance,
    required this.trafficInfo,
    required this.onClear,
    required this.isDriving,
  });

  @override
  Widget build(BuildContext context) {
    if (destination.isEmpty) return const SizedBox.shrink();

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // 🎯 동적 크기 계산 (검색바와 연계)
    final searchBarTopMargin = screenHeight * 0.02; // 검색바 위쪽 여백 (search_bar.dart와 동일)
    final searchBarHeight = screenHeight * 0.055;   // 검색바 높이 (search_bar.dart와 동일)
    final gapBetweenWidgets = screenHeight * 0.01;  // 검색바와 목적지 정보 사이 간격 (1%)

    final cardHeight = screenHeight * 0.11; // 화면 높이의 11%
    final horizontalMargin = screenWidth * 0.04; // 검색바와 동일한 가로 마진
    final horizontalPadding = screenWidth * 0.04; // 내부 패딩

    // 🔄 운전 상태에 따른 동적 위치 계산
    final dynamicTop = isDriving
        ? searchBarTopMargin + gapBetweenWidgets // 운전 중: 검색바 없으니 위쪽으로
        : searchBarTopMargin + searchBarHeight + gapBetweenWidgets; // 운전 안함: 검색바 아래

    return Positioned(
      top: dynamicTop, // 🔄 동적 위치 계산 (기존 100 → dynamicTop)
      left: horizontalMargin,
      right: horizontalMargin,
      child: Container(
        height: cardHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(horizontalPadding),
          child: Row(
            children: [
              // 🎯 목적지 아이콘
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Colors.white,
                  size: 16,
                ),
              ),

              SizedBox(width: horizontalPadding * 0.5),

              // 📍 목적지 정보 (확장)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 목적지 이름
                    Text(
                      destination,
                      style: TextStyle(
                        fontSize: screenHeight * 0.020,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    SizedBox(height: screenHeight * 0.004),

                    // 시간과 거리 정보 (아이콘 + 숫자)
                    Row(
                      children: [
                        // ⏱️ 시간 아이콘 + 숫자
                        Icon(
                          Icons.access_time,
                          size: screenHeight * 0.018,
                          color: Colors.blue[600],
                        ),
                        SizedBox(width: screenWidth * 0.01),
                        Text(
                          _formatTimeToMinutes(estimatedTime), // 분만 표시
                          style: TextStyle(
                            fontSize: screenHeight * 0.020, // 크기 증가 (0.016 → 0.020)
                            fontWeight: FontWeight.bold, // w600 → bold
                            color: Colors.blue[600],
                          ),
                        ),

                        SizedBox(width: horizontalPadding * 0.5),

                        // 📏 거리 아이콘 + 숫자
                        Icon(
                          Icons.straighten,
                          size: screenHeight * 0.018,
                          color: Colors.grey[600],
                        ),
                        SizedBox(width: screenWidth * 0.01),
                        Text(
                          estimatedDistance,
                          style: TextStyle(
                            fontSize: screenHeight * 0.014, // 크기 감소 (0.016 → 0.014)
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ✕ 닫기 버튼
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onClear,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.close,
                      color: Colors.grey[600],
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🕐 초만 제거하고 시간은 그대로 유지하는 함수
  String _formatTimeToMinutes(String timeString) {
    return timeString.replaceAll(RegExp(r'\s*\d+초'), '');
  }
}