import 'package:flutter/material.dart';

class LevelBadge extends StatelessWidget {
  final int level;
  final double size;
  final bool showLabel;

  const LevelBadge({
    Key? key,
    required this.level,
    this.size = 40,
    this.showLabel = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showLabel)
              Text("LVL",
                  style: TextStyle(
                      fontSize: size * 0.16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
            Text("$level",
                style: TextStyle(
                    fontSize: size * 0.35,
                    fontWeight: FontWeight.w900,
                    color: Colors.black)),
          ],
        ),
      ),
    );
  }
}
