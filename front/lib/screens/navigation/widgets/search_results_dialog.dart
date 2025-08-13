import 'package:flutter/material.dart';
import 'dart:ui';

class SearchResultsDialog extends StatelessWidget {
  final List<Map<String, dynamic>> results;
  final Function(Map<String, dynamic>) onSelect;

  const SearchResultsDialog({
    super.key,
    required this.results,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // 🎯 동적 크기 계산
    final maxDialogHeight = screenHeight * 0.6; // 화면 높이의 60%
    final headerHeight = screenHeight * 0.07;   // 화면 높이의 7%
    final titleFontSize = screenHeight * 0.022; // 화면 높이의 2.2%
    final horizontalPadding = screenWidth * 0.02; // 화면 너비의 2% (더 넓게)

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxDialogHeight),
        margin: EdgeInsets.symmetric(horizontal: horizontalPadding),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[850],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 헤더
                Container(
                  height: headerHeight,
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding * 2),
                  decoration: BoxDecoration(
                    color: Colors.teal[600],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '검색 결과',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.close,
                              color: Colors.white,
                              size: titleFontSize * 0.8,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 결과 목록
                Flexible(
                  child: results.isEmpty
                      ? Container(
                    padding: EdgeInsets.all(horizontalPadding * 2),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[700],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.search_off,
                            color: Colors.grey[400],
                            size: screenHeight * 0.035,
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.015),
                        Text(
                          '검색 결과가 없습니다.',
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: screenHeight * 0.018,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                      : ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero, // 패딩 제거로 간격 줄임
                    itemCount: results.length,
                    separatorBuilder: (context, index) => Divider(
                      color: Colors.grey[700],
                      thickness: 0.5,
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                    ),
                    itemBuilder: (context, index) {
                      final result = results[index];
                      return ListTile(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding * 2, // 내부 패딩은 유지
                          vertical: 4, // 상하 패딩 늘림
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.teal[600],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: screenHeight * 0.022,
                          ),
                        ),
                        title: Text(
                          result['placeName'] ?? '알 수 없는 장소',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: screenHeight * 0.018,
                            color: Colors.white,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 일반 주소
                            // if (result['address'] != null && result['address'].isNotEmpty)
                            //   Text(
                            //     result['address'],
                            //     style: TextStyle(
                            //       fontSize: screenHeight * 0.015,
                            //       color: Colors.grey[300],
                            //     ),
                            //   ),

                            // 도로명 주소
                            if (result['roadAddress'] != null && result['roadAddress'].isNotEmpty)
                              Text(
                                result['roadAddress'],
                                style: TextStyle(
                                  fontSize: screenHeight * 0.014,
                                  color: Colors.grey[400],
                                ),
                              ),
                            // 위도, 경도
                            // Text(
                            //   '위도: ${result['latitude']?.toStringAsFixed(6) ?? 'N/A'}, '
                            //       '경도: ${result['longitude']?.toStringAsFixed(6) ?? 'N/A'}',
                            //   style: TextStyle(
                            //     fontSize: screenHeight * 0.012,
                            //     color: Colors.grey[500],
                            //   ),
                            // ),
                          ],
                        ),
                        onTap: () {
                          onSelect(result);
                          Navigator.of(context).pop();
                        },
                      );
                    },
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