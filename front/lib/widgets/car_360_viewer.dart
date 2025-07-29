import 'package:flutter/material.dart';

class Car360Viewer extends StatefulWidget {
  final List<String> imagePaths; // 360도 회전을 위한 이미지 경로 리스트
  final double sensitivity; // 드래그 민감도 (값이 클수록 적은 드래그로 많은 이미지 변화)
  final double? width; // 뷰어의 너비 (선택 사항)
  final double? height; // 뷰어의 높이 (선택 사항)

  const Car360Viewer({
    super.key,
    required this.imagePaths,
    this.sensitivity = 5.0, // 기본 민감도 조절 (픽셀 당 이미지 변화 정도)
    this.width,
    this.height,
  });

  @override
  State<Car360Viewer> createState() => _Car360ViewerState();
}

class _Car360ViewerState extends State<Car360Viewer> {
  int _currentIndex = 0; // 현재 보여지는 이미지 인덱스
  double _lastDragX = 0.0; // 이전 드래그 X 좌표

  @override
  void didUpdateWidget(covariant Car360Viewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 이미지 경로 리스트가 변경되면 현재 인덱스를 초기화합니다.
    if (widget.imagePaths != oldWidget.imagePaths) {
      _currentIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 이미지 경로가 비어있으면 로딩 인디케이터를 표시
    if (widget.imagePaths.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).primaryColor,
        ),
      );
    }

    return GestureDetector(
      onPanStart: (details) {
        _lastDragX = details.globalPosition.dx;
      },
      onPanUpdate: (details) {
        final double dragDistance = details.globalPosition.dx - _lastDragX;
        // 드래그 거리를 이미지 인덱스 변화량으로 변환
        // sensitivity 값에 따라 한 번의 드래그에 몇 개의 이미지가 넘어갈지 조절됩니다.
        // 드래그 방향에 따라 인덱스를 증감시킵니다.
        // 오른쪽으로 드래그 (dragDistance > 0) 시 인덱스 감소 (시각적으로 오른쪽 회전)
        // 왼쪽으로 드래그 (dragDistance < 0) 시 인덱스 증가 (시각적으로 왼쪽 회전)
        final int imageChange = (dragDistance / widget.sensitivity).round();

        if (imageChange != 0) {
          setState(() {
            // 새로운 인덱스 계산
            int newIndex = _currentIndex - imageChange;

            // 인덱스가 이미지 리스트 범위를 벗어나지 않도록 조정 (음수 및 초과 값 처리)
            final int numImages = widget.imagePaths.length;
            newIndex = newIndex % numImages; // 먼저 나머지 연산을 수행
            if (newIndex < 0) { // 음수일 경우 양수로 변환
              newIndex += numImages;
            }
            _currentIndex = newIndex;

            _lastDragX = details.globalPosition.dx; // 현재 드래그 위치를 다음 시작점으로 업데이트
          });
        }
      },
      child: Image.asset(
        widget.imagePaths[_currentIndex],
        fit: BoxFit.contain, // 이미지 비율 유지
        width: widget.width,
        height: widget.height,
        // 이미지가 로드되기 전의 배경색을 설정하여 깜빡임 줄이기
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) {
            return child;
          }
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 100),
            child: child,
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return const Center(child: Text('이미지를 로드할 수 없습니다.', style: TextStyle(color: Colors.red)));
        },
      ),
    );
  }
}