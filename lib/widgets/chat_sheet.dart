// lib/widgets/chat_sheet.dart
import 'package:flutter/material.dart';

class ChatSheet extends StatelessWidget {
  const ChatSheet({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 520,
      decoration: const BoxDecoration(
          color: Color(0xFF14161b),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        children: [
          Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Chat History',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop())
                  ])),
          Expanded(
            child: ListView(padding: const EdgeInsets.all(16), children: [
              _msgRow('Good luck!', 'assets/avatars/a4.png', isMe: false),
              const SizedBox(height: 12),
              _msgRow('You too!', 'assets/avatars/a1.png', isMe: true),
              const SizedBox(height: 20),
            ]),
          ),
          Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(30)),
                    child: const TextField(
                      decoration: InputDecoration(
                          border: InputBorder.none, hintText: 'Type a message'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                    child: IconButton(
                        icon: const Icon(Icons.send), onPressed: () {}),
                    radius: 22)
              ]))
        ],
      ),
    );
  }

  Widget _msgRow(String text, String avatar, {bool isMe = false}) {
    return Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe)
            CircleAvatar(radius: 16, backgroundImage: AssetImage(avatar)),
          if (!isMe) const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: isMe ? null : Colors.white12,
              gradient: isMe
                  ? const LinearGradient(
                      colors: [Color(0xFFA259FF), Color(0xFF3B82F6)])
                  : null,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(text,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          if (isMe) const SizedBox(width: 8),
          if (isMe)
            CircleAvatar(radius: 16, backgroundImage: AssetImage(avatar)),
        ]);
  }
}
