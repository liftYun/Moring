import 'package:flutter/material.dart';
import 'dart:ui';

class DestinationSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSearch;
  final bool isSearching;
  final Function(bool)? onFocusChanged;

  const DestinationSearchBar({
    super.key,
    required this.controller,
    required this.onSearch,
    required this.isSearching,
    this.onFocusChanged,
  });

  @override
  State<DestinationSearchBar> createState() => _DestinationSearchBarState();
}

class _DestinationSearchBarState extends State<DestinationSearchBar> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      // debugPrint('🎹 검색바 포커스 상태: ${_focusNode.hasFocus}');
      widget.onFocusChanged?.call(_focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // 🎯 동적 크기 계산
    final dynamicMargin = screenHeight * 0.02;       // 화면 높이의 2%
    final searchBarHeight = screenHeight * 0.055;    // 화면 높이의 5.5% (약 40-60px)
    final searchButtonSize = searchBarHeight;        // 정사각형 유지
    final horizontalPadding = screenWidth * 0.04;    // 화면 너비의 4%
    final spaceBetween = screenWidth * 0.03;         // 검색창과 버튼 사이 간격

    return Positioned(
      top: dynamicMargin,
      left: horizontalPadding,    // 동적 좌측 여백
      right: horizontalPadding,   // 동적 우측 여백
      child: Row(
        children: [
          // 📍 메인 검색창 (동적 크기)
          Expanded(
            child: Container(
              height: searchBarHeight, // 동적 높이
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8), // 카카오맵 스타일: 약간만 둥근 모서리
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                style: TextStyle(
                  fontSize: searchBarHeight * 0.33, // 동적 폰트 크기 (검색바 높이의 33%)
                  fontWeight: FontWeight.w400,
                  color: Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: '어디로 갈까요?',
                  hintStyle: TextStyle(
                    color: Colors.grey[500],
                    fontSize: searchBarHeight * 0.33, // 힌트 텍스트도 동적 크기
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: searchBarHeight * 0.42, // 동적 수평 패딩
                    vertical: searchBarHeight * 0.29,   // 동적 수직 패딩
                  ),
                  // 마이크 아이콘 제거 (suffixIcon 없음)
                ),
                onSubmitted: (_) => widget.onSearch(),
              ),
            ),
          ),

          SizedBox(width: spaceBetween), // 동적 간격

          // 🔍 검색 버튼 (동적 크기)
          Container(
            width: searchButtonSize,  // 검색바 높이와 동일 (정사각형)
            height: searchButtonSize,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.teal[400]!, // 원래 teal 색상 유지
                  Colors.teal[600]!,
                ],
              ),
              borderRadius: BorderRadius.circular(8), // 검색창과 동일한 둥근 정도
              boxShadow: [
                BoxShadow(
                  color: Colors.teal.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onSearch,
                borderRadius: BorderRadius.circular(8),
                child: const Center(
                  child: Icon(
                    Icons.search,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}