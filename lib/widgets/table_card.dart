import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'glass_container.dart';

class TableCard extends StatelessWidget {
  final String mode;
  final String winText;
  final int? entryFee;
  final String? entryLabel; // Fallback for "2.5k Gold" or "Full"
  final VoidCallback? onTap;
  final bool isActive;
  final bool isTeam;

  const TableCard({
    Key? key,
    required this.mode,
    required this.winText,
    this.entryFee,
    this.entryLabel,
    this.onTap,
    this.isActive = false,
    this.isTeam = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determine display string for cost
    String costString;
    if (entryFee != null) {
      if (entryFee! >= 1000) {
        costString = '${(entryFee! / 1000).toStringAsFixed(1)}k Gold';
      } else {
        costString = '$entryFee Gold';
      }
    } else {
      costString = entryLabel ?? '';
    }

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          GlassContainer(
            borderRadius: 24,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
            color: const Color(0xffffffff).withOpacity(0.05), // Light glass
            child: Column(
              children: [
                // 1. TOP ROW: Badge + Win Amount
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white54, width: 1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        mode,
                        style: AppTheme.label.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white70),
                      ),
                    ),
                    Text(
                      winText,
                      style: AppTheme.label.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        foreground: Paint()
                          ..shader = const LinearGradient(
                            colors: [AppTheme.neonPurple, AppTheme.neonBlue],
                          ).createShader(
                              const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // 2. MID ROW: Avatars vs Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Avatars
                    Expanded(
                        child:
                            isTeam ? _buildTeamAvatars() : _build1v1Avatars()),

                    // Join Button or "Watching..."
                    if (isActive)
                      const Text(
                        "Watching...",
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white38,
                            fontStyle: FontStyle.italic),
                      )
                    else
                      _buildJoinButton(costString),
                  ],
                ),

                const SizedBox(height: 12),

                // 3. BOTTOM ROW: Status
                Container(
                  padding: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(
                    border: Border(
                        top: BorderSide(color: Colors.white.withOpacity(0.05))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Entry: $costString",
                        style: const TextStyle(
                            fontSize: 10, color: Colors.white38),
                      ),
                      Text(
                        isActive ? "Playing" : "Open",
                        style: TextStyle(
                            fontSize: 10,
                            color:
                                isActive ? Colors.white38 : AppTheme.neonGreen),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),

          // Neon Strip (Left)
          Positioned(
            left: 16,
            top: 0,
            bottom: 16,
            width: 4,
            child: Container(
              decoration: const BoxDecoration(
                  gradient: AppTheme.primaryGrad,
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      bottomLeft: Radius.circular(24))),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildJoinButton(String cost) {
    // We already show cost at bottom, so button can be simpler or duplicate info.
    // Design has "JOIN (icon) 1.0k". Cost string here has "Gold" appended, let's strip it for button.
    final shortCost = cost.replaceAll(' Gold', '');

    return Container(
      decoration: const BoxDecoration(
          gradient: AppTheme.primaryGrad,
          borderRadius: BorderRadius.all(Radius.circular(20)),
          boxShadow: [
            BoxShadow(
                color: AppTheme.neonPurple,
                blurRadius: 10,
                offset: Offset(0, 4),
                spreadRadius: -2)
          ]),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text(
            "JOIN",
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.monetization_on,
              size: 12,
              color: Colors.white), // Use white for contrast on gradient
          const SizedBox(width: 2),
          Text(
            shortCost,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _build1v1Avatars() {
    return Row(
      children: [
        _avatar('assets/avatars/a5.png'), // Mock P1
        const SizedBox(width: 8),
        const Text("VS",
            style: TextStyle(
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                color: Colors.white24,
                fontSize: 14)),
        const SizedBox(width: 8),
        isActive
            ? _avatar('assets/avatars/a3.png')
            : const SizedBox(), // Empty slot if open
      ],
    );
  }

  Widget _buildTeamAvatars() {
    // 2 vs 2 Layout
    return Row(
      children: [
        // Team A (Stacked)
        SizedBox(
          width: 50, // 36 + overlap
          height: 36,
          child: Stack(
            children: [
              _avatar('assets/avatars/a3.png'),
              Positioned(left: 20, child: _avatar('assets/avatars/a4.png')),
            ],
          ),
        ),
        const SizedBox(width: 6),
        const Text("VS",
            style: TextStyle(
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                color: Colors.white24,
                fontSize: 14)),
        const SizedBox(width: 6),
        // Team B (One joined + One empty/plus)
        SizedBox(
          width: 50,
          height: 36,
          child: Stack(
            children: [
              _avatar('assets/avatars/a5.png'), // P3
              // P4 Slot (Active or Empty)
              isActive
                  ? Positioned(
                      left: 20, child: _avatar('assets/avatars/a1.png'))
                  : Positioned(
                      left: 20,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white30,
                                style: BorderStyle
                                    .solid), // Dashed hard in flutter, solid ok
                            color: Colors.white10),
                        child: const Icon(Icons.add,
                            size: 16, color: Colors.white54),
                      ))
            ],
          ),
        ),
      ],
    );
  }

  Widget _avatar(String path) {
    return Container(
      width: 36, // Slightly larger
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 1),
        image: DecorationImage(image: AssetImage(path), fit: BoxFit.cover),
      ),
    );
  }
}
