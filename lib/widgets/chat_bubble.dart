import 'package:flutter/material.dart';

class ChatBubble extends StatelessWidget {
  final String? text;

  const ChatBubble({super.key, this.text});

  @override
  Widget build(BuildContext context) {
    if (text == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text!,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
    );
  }
}
