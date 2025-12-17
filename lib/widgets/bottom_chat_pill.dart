import 'package:flutter/material.dart';
import 'chat_sheet.dart';

class BottomChatPill extends StatelessWidget {
  const BottomChatPill({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: 14, top: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [Color(0xFF0F1218), Colors.transparent],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter),
      ),
      child: Center(
        child: GestureDetector(
          onTap: () => _openChat(context),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: 48,
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white10)),
            child: Row(children: [
              SizedBox(width: 10),
              CircleAvatar(
                  radius: 16,
                  backgroundImage: AssetImage('assets/avatars/a1.png')),
              SizedBox(width: 10),
              Expanded(
                  child: Text('Tap to chat...',
                      style: TextStyle(
                          fontSize: 12, color: Colors.white.withOpacity(0.9)))),
              Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(Icons.emoji_emotions, color: Colors.white54))
            ]),
          ),
        ),
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
