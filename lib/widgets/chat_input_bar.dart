import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'glass_container.dart';

class ChatInputBar extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final Function(String)? onChanged;
  final String hintText;
  final bool isLoading;

  const ChatInputBar({
    Key? key,
    required this.controller,
    required this.onSend,
    this.onChanged,
    this.hintText = "Type a message...",
    this.isLoading = false,
  }) : super(key: key);

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 0,
      // Handle safe area bottom padding if needed, usually handled by parent or Scaffold
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(0xFF1E2025).withOpacity(0.8), // Slightly darker glass
      borderColor: Colors.white10,
      borderOpacity: 0.1,
      child: Row(
        children: [
          // Optional: Add Attachment button here if needed later
          // IconButton(
          //     onPressed: () {},
          //     icon: const Icon(Icons.add_circle_outline, color: Colors.white54)),

          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white10)),
              child: TextField(
                controller: widget.controller,
                style: const TextStyle(color: Colors.white),
                onChanged: widget.onChanged,
                onSubmitted: (_) => widget.onSend(),
                decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: const TextStyle(color: Colors.white30),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Unified Send Button (Purple Circle)
          GestureDetector(
            onTap: widget.isLoading ? null : widget.onSend,
            child: CircleAvatar(
              backgroundColor: AppTheme.neonBlue,
              radius: 20,
              child: widget.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send, color: Colors.white, size: 18),
            ),
          )
        ],
      ),
    );
  }
}
