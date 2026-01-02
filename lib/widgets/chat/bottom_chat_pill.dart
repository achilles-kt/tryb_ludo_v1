import 'package:flutter/material.dart';
import 'chat_sheet.dart';

class BottomChatPill extends StatelessWidget {
  const BottomChatPill({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openChat(context),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: 48,
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white10)),
        child: Row(children: [
          const SizedBox(width: 10),
          const CircleAvatar(
              radius: 16, backgroundImage: AssetImage('assets/avatars/a1.png')),
          const SizedBox(width: 10),
          Expanded(
              child: Text('Tap to chat...',
                  style: TextStyle(
                      fontSize: 12, color: Colors.white.withOpacity(0.9)))),
          const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.emoji_emotions, color: Colors.white54))
        ]),
      ),
    );
  }

  void _openChat(BuildContext ctx) {
    showModalBottomSheet(
        context: ctx,
        isScrollControlled: true,
        backgroundColor: Color(0xFF14161b),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => ChatSheet());
  }
}
