import 'package:flutter/material.dart';
import 'dart:ui';

class DestinationInfo extends StatelessWidget {
  final String destination;
  final String estimatedTime;
  final String estimatedDistance;
  final String trafficInfo;
  final VoidCallback onClear;
  
  const DestinationInfo({
    super.key,
    required this.destination,
    required this.estimatedTime,
    required this.estimatedDistance,
    required this.trafficInfo,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (destination.isEmpty) return const SizedBox.shrink();
    
    return Positioned(
      top: 180,
      left: 20,
      right: 20,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.9),
                    Colors.white.withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.red[400]!,
                              Colors.red[600]!,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          destination,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onClear,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
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
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildInfoItem(Icons.access_time, estimatedTime, '예상 시간')),
                      const SizedBox(width: 16),
                      Expanded(child: _buildInfoItem(Icons.straighten, estimatedDistance, '거리')),
                      const SizedBox(width: 16),
                      Expanded(child: _buildInfoItem(Icons.traffic, trafficInfo, '교통상황')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildInfoItem(IconData icon, String text, String label) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue[50]!,
            Colors.blue[100]!,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue[400]!,
                  Colors.blue[600]!,
                ],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
