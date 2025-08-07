import 'package:flutter/material.dart';

class SpeedOverlay extends StatelessWidget {
  final String currentSpeed;
  final bool isDriving;
  
  const SpeedOverlay({
    super.key,
    required this.currentSpeed,
    required this.isDriving,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 60,
      left: 20,
      child: Text(
        currentSpeed,
        style: TextStyle(
          color: isDriving ? Colors.green : Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 4,
              offset: const Offset(1, 1),
            ),
          ],
        ),
      ),
    );
  }
}
