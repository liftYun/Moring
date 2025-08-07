import 'package:flutter/material.dart';
import 'package:moring/widgets/car_360_viewer.dart';

/// 차량 360° 뷰어 섹션
class CarViewerSection extends StatelessWidget {
  final List<String> imagePaths;
  const CarViewerSection({super.key, required this.imagePaths});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: Colors.grey[900],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Car360Viewer(
          imagePaths: imagePaths,
          sensitivity: 10.0,
          width: double.infinity,
          height: 250,
        ),
      ),
    );
  }
}
