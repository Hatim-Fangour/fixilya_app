import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class PremiumStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final List<Color> gradient;
  final Color iconColor;

  const PremiumStatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.gradient,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: iconColor.withValues(alpha: 0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: iconColor.withValues(alpha: 0.15),
            blurRadius: 15,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: iconColor.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: FaIcon(icon, color: iconColor, size: 22),
          ),
          SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
