import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class SocialHeader extends StatelessWidget {
  final VoidCallback onAddFriend;

  const SocialHeader({Key? key, required this.onAddFriend}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Social Hub",
            style: AppTheme.header.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          InkWell(
            onTap: onAddFriend,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.neonBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.neonBlue.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.person_add, // mapped from ph-user-plus
                color: AppTheme.neonBlue,
                size: 20,
              ),
            ),
          )
        ],
      ),
    );
  }
}
