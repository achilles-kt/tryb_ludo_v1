import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/chat/bottom_chat_pill.dart';

class LobbyFloatingControls extends StatelessWidget {
  final VoidCallback onPlayTap;

  const LobbyFloatingControls({super.key, required this.onPlayTap});

  @override
  Widget build(BuildContext context) {
    // Use Align instead of Positioned(left:0, right:0, child: Center())
    // to prevent invisible full-width containers from blocking touches.
    return Stack(
      children: [
        Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
                padding: const EdgeInsets.only(bottom: 73), child: _playBtn())),
        const Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
                padding: EdgeInsets.only(bottom: 10), child: BottomChatPill())),
      ],
    );
  }

  Widget _playBtn() {
    return GestureDetector(
      onTap: onPlayTap,
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
            gradient: AppTheme.primaryGrad,
            borderRadius: BorderRadius.circular(50),
            boxShadow: [
              BoxShadow(
                  color: AppTheme.neonPurple.withOpacity(0.28),
                  blurRadius: 40,
                  offset: const Offset(0, 10))
            ],
            border:
                Border.all(color: Colors.white.withOpacity(0.12), width: 3)),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.play_arrow, color: Colors.white, size: 32),
              SizedBox(height: 4),
              Text('PLAY',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      color: Colors.white))
            ]),
      ),
    );
  }
}
