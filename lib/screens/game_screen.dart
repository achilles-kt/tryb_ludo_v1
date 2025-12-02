import 'package:flutter/material.dart';
import '../constants.dart';

class GameScreen extends StatelessWidget {
  final String gameId;
  GameScreen({required this.gameId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Stack(
          children: [
            Center(child: _boardContainer()),
            Positioned(
                left: 16,
                top: 20,
                child: _playerSpot('You', 'assets/avatars/a1.png')),
            Positioned(
                right: 16,
                top: 20,
                child: _playerSpot('Marcus', 'assets/avatars/a2.png')),
            Positioned(
                left: 16,
                bottom: 120,
                child: _playerSpot('Opp1', 'assets/avatars/a3.png')),
            Positioned(
                right: 16,
                bottom: 120,
                child: _playerSpot('Opp2', 'assets/avatars/a4.png')),
            Positioned(
                bottom: 40,
                left: MediaQuery.of(context).size.width / 2 - 35,
                child: FloatingActionButton(
                    onPressed: () {}, child: Icon(Icons.casino))),
          ],
        ),
      ),
    );
  }

  Widget _boardContainer() {
    return Container(
      width: 340,
      height: 340,
      decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white12)),
      child: Stack(
        children: [
          // four corner homes
          Positioned(
              left: 8, top: 8, child: _homeBox(color: AppColors.neonRed)),
          Positioned(
              right: 8, top: 8, child: _homeBox(color: AppColors.neonYellow)),
          Positioned(
              left: 8, bottom: 8, child: _homeBox(color: AppColors.neonGreen)),
          Positioned(
              right: 8, bottom: 8, child: _homeBox(color: AppColors.neonBlue)),
          // center box
          Center(
              child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(10)))),
        ],
      ),
    );
  }

  Widget _homeBox({required Color color}) {
    return Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2))),
        child: Padding(
            padding: EdgeInsets.all(10),
            child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: List.generate(
                    4,
                    (i) => Container(
                        decoration: BoxDecoration(
                            color: color, shape: BoxShape.circle))))));
  }

  Widget _playerSpot(String name, String avatar) {
    return Row(children: [
      CircleAvatar(radius: 28, backgroundImage: AssetImage(avatar)),
      SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: TextStyle(fontWeight: FontWeight.w700)),
        SizedBox(height: 4),
        Text('Level 12',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted))
      ])
    ]);
  }
}
