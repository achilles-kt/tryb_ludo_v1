import 'package:flutter/material.dart';
import '../currency/gold_balance_widget.dart';

class GameTopBar extends StatelessWidget {
  const GameTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.08))),
          child: Row(
            children: [
              // Back Button
              GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: const Icon(Icons.arrow_back_ios_new,
                      size: 18, color: Colors.white70)),
              const SizedBox(width: 16),

              // Title or Game ID
              const Text("Game Room",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),

              const Spacer(),
              const GoldBalanceWidget(),
            ],
          ),
        ),
      ),
    );
  }
}
