import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flame/game.dart' hide Matrix4;
import 'package:firebase_auth/firebase_auth.dart';
import '../game/ludo_game.dart';
import '../widgets/game/end_game_overlay.dart';
import '../widgets/chat_sheet.dart';
import '../state/game_state.dart';
import '../state/game_state.dart';
import '../widgets/gold_balance_widget.dart';
import '../widgets/game/game_player_profile.dart';

import '../widgets/game/chat_overlay.dart';
import '../widgets/game/dice_sprite_widget.dart'; // Sprite Dice
import '../services/presence_service.dart';
import '../services/chat_service.dart'; // ActivityService

class GameScreen extends StatefulWidget {
  final String gameId;
  final String tableId;

  const GameScreen({
    super.key,
    required this.gameId,
    required this.tableId,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late LudoGame game;
  Timer? _timer;

  // Track active widgets
  // Chat logic moved to ChatOverlay
  bool _isTeamChat = false;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

    // Presence: Set Playing
    PresenceService().setPlaying(widget.gameId);

    game = LudoGame(
      gameId: widget.gameId,
      tableId: widget.tableId,
      localUid: uid,
      onMoveCompleted: _refreshUI,
      onGameOver: _showEndScreen,
    );

    debugPrint('Game Screen Open and visible | Success | $uid');

    // Refresh UI periodically for timer animation/game loop sync
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    // Presence: Set back to Online (Idle)
    PresenceService().setOnline();
    _timer?.cancel();
    super.dispose();
  }

  void _refreshUI() {
    if (mounted) setState(() {});
  }

  void _showEndScreen(GameResult result) {
    // Activity Stream: Log Game Result
    try {
      final allUids = game.state.players.keys.toList();
      final convId = ActivityService.instance.getCanonicalId(allUids);

      final winnerUid = result == GameResult.win
          ? game.localUid
          : (game.winnerUid ?? 'Unknown');

      // Helper to get name
      String getName(String id) => game.state.players[id]?['name'] ?? 'Player';
      final winnerName = getName(winnerUid);

      ActivityService.instance.sendMessageToConversation(
        convId: convId,
        text: "Game Finished. Winner: $winnerName 🏆",
        type: "game_result",
        payload: {
          "result": result == GameResult.win ? "win" : "loss",
          "winnerUid": winnerUid,
          "gameId": widget.gameId
        },
      );
    } catch (e) {
      debugPrint("Error logging game result: $e");
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => EndGameOverlay(game: game),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Background handled by container
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.3,
            colors: [
              Color(0xFF1E293B), // Spot of light in center
              Color(0xFF0F1218), // Dark corners
            ],
            stops: [0.0, 0.9],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenW = constraints.maxWidth;
            final screenH = constraints.maxHeight;

            // Define safe area for board
            // TopBar is ~80px, BottomArea is ~100px.
            // Add padding (24px top, 24px bottom).
            final safeHeight = screenH - 180;

            // Board is a square. Constrain by width (90%) AND available height.
            final boardSize = (screenW * 0.90).clamp(0.0, safeHeight);

            // Center board vertically in the safe zone
            // But bias slightly upwards (-20) as before if space allows
            final availableVerticalSpace = screenH - boardSize;
            final boardTop = (availableVerticalSpace / 2 - 20)
                .clamp(80.0, screenH - boardSize - 80.0);
            final boardLeft = (screenW - boardSize) / 2;

            return Stack(
              children: [
                // ---------------- TOP BAR ----------------
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _TopBar(),
                ),

                // ---------------- BOARD (FLAME) ----------------
                Positioned(
                  left: boardLeft,
                  top: boardTop,
                  width: boardSize,
                  height: boardSize,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: GameWidget(game: game),
                  ),
                ),

                // ---------------- AVATARS ----------------
                // Dynamically render avatars based on visual seats
                // Visual 0 = BL (Me), 1 = TL, 2 = TR, 3 = BR
                for (int visualSeat = 0; visualSeat < 4; visualSeat++) ...[
                  if (game.getPlayerMetaByVisualSeat(visualSeat) != null)
                    _buildAvatarAtVisualSeat(context, visualSeat, boardLeft,
                        boardTop, boardSize, game),
                ],

                // ---------------- DICE POSITIONS ----------------
                _buildDice(boardLeft, boardTop, boardSize),

                // ---------------- FLYING BUBBLES & STATIC ----------------
                Positioned.fill(
                  child: ChatOverlay(
                    gameId: widget.gameId,
                    players: game.state.players,
                    localPlayerIndex: game.state.localPlayerIndex,
                    boardRect: Rect.fromLTWH(
                      boardLeft,
                      boardTop,
                      boardSize,
                      boardSize,
                    ),
                  ),
                ),

                // ---------------- BOTTOM CHAT PILL ----------------
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _BottomArea(
                    gameId: widget.gameId,
                    isTeamChat: _isTeamChat,
                    showTeamToggle: game.state.players.length > 2,
                    players: game.state.players,
                    onToggleTeam: () =>
                        setState(() => _isTeamChat = !_isTeamChat),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDice(double boardLeft, double boardTop, double boardSize) {
    // Phase 2: Listen to Central Controller
    return ValueListenableBuilder<GameState>(
      valueListenable: game.controller.gameState,
      builder: (context, state, _) {
        final isYourTurn = state.currentPlayer == state.localPlayerIndex;
        final phase = state.turnPhase;
        final isRolling = game
            .isRollingNotifier.value; // Use local notifier for Position logic

        double targetLeft;
        double targetTop;
        double targetSize = 56; // Standard size

        bool isCenter = phase == TurnPhase.rollingAnim || isRolling;

        if (isCenter) {
          targetLeft = boardLeft + boardSize / 2 - 60;
          targetTop = boardTop + boardSize / 2 - 60;
          targetSize = 120;
        } else {
          // Calculate visual seat of the current turn owner
          final int serverSeat = state.currentPlayer;
          final int localSeat = state.localPlayerIndex;
          final int visualSeat = (serverSeat - localSeat + 4) % 4;

          final double screenW = MediaQuery.of(context).size.width;

          switch (visualSeat) {
            case 0: // Bottom-Left (Me)
              // Right of Avatar
              targetLeft = 16 + 44 + 12;
              targetTop = boardTop + boardSize + 32;
              targetSize = 64; // Larger for me
              break;
            case 1: // Top-Left
              // Right of Avatar
              targetLeft = 16 + 44 + 12;
              targetTop = boardTop - 64;
              targetSize = 48;
              break;
            case 2: // Top-Right
              // Left of Avatar
              targetLeft = screenW - 16 - 44 - 12 - 48;
              targetTop = boardTop - 64;
              targetSize = 48;
              break;
            case 3: // Bottom-Right
              // Left of Avatar
              targetLeft = screenW - 16 - 44 - 12 - 48;
              targetTop = boardTop + boardSize + 32;
              targetSize = 48;
              break;
            default:
              targetLeft = 24;
              targetTop = boardTop + boardSize + 24;
          }
        }

        return AnimatedPositioned(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          left: targetLeft,
          top: targetTop,
          width: targetSize,
          height: targetSize,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              if (isYourTurn && phase == TurnPhase.waitingRoll) {
                game.rollDice();
              }
            },
            child: DiceSpriteWidget(
              controller: game.controller,
              size: targetSize,
              timeLeft: _calculateTimeLeft(state),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatarAtVisualSeat(BuildContext context, int visualSeat,
      double boardLeft, double boardTop, double boardSize, LudoGame game) {
    final meta = game.getPlayerMetaByVisualSeat(visualSeat);
    if (meta == null) return const SizedBox.shrink();

    double? top, left, right;

    // Position Logic
    switch (visualSeat) {
      case 0: // Bottom-Left (Me)
        top = boardTop + boardSize + 32;
        left = 16;
        break;
      case 1: // Top-Left
        top = boardTop - 64;
        left = 16;
        break;
      case 2: // Top-Right (Opponent or Teammate)
        top = boardTop - 64;
        right = 16;
        break;
      case 3: // Bottom-Right
        top = boardTop + boardSize + 32;
        right = 16;
        break;
    }

    // Determine if it's this player's turn
    final isTurn = game.currentTurnUidNotifier.value == meta.uid;

    return Positioned(
      top: top,
      left: left,
      right: right,
      child: ValueListenableBuilder<String?>(
          valueListenable: game.currentTurnUidNotifier,
          builder: (context, currentTurnUid, _) {
            // Re-evaluate turn inside builder for reactivity
            final activeTurn = currentTurnUid == meta.uid;
            return GamePlayerProfile(
              uid: meta.uid,
              fallbackName: meta.name ?? 'Player',
              fallbackAvatar: meta.avatarUrl,
              isMe: meta.isYou,
              isTeam: meta.isTeam,
              isTurn: activeTurn,
              teamColor: meta.glowColor,
            );
          }),
    );
  }

  double _calculateTimeLeft(GameState state) {
    if (state.turnPhase != TurnPhase.waitingRoll) return 0.0;
    if (state.turnDeadlineTs == null) return 0.0;

    final now = DateTime.now().millisecondsSinceEpoch;
    final total = 10000; // 10s (Matches backend)
    final remaining = state.turnDeadlineTs! - now;
    return (remaining / total).clamp(0.0, 1.0);
  }
}

class _TopBar extends StatelessWidget {
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
                  onTap: () => Navigator.of(context).pop(),
                  child: Icon(Icons.arrow_back_ios_new,
                      size: 18, color: Colors.white70)),
              const SizedBox(width: 16),

              // Title or Game ID
              Text("Game Room",
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

class _BottomArea extends StatelessWidget {
  final String? gameId;
  final bool isTeamChat;
  final bool showTeamToggle;
  final VoidCallback? onToggleTeam;
  final Map<String, dynamic>? players;

  const _BottomArea({
    this.gameId,
    this.isTeamChat = false,
    this.showTeamToggle = true,
    this.onToggleTeam,
    this.players,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    return Container(
      padding: const EdgeInsets.only(bottom: 24, top: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xCC0F1218), Colors.transparent],
        ),
      ),
      child: Center(
        child: GestureDetector(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: const Color(0xFF14161b),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (_) => ChatSheet(
                gameId: gameId,
                initialIsTeamChat: isTeamChat,
                showTeamToggle: showTeamToggle,
                players: players,
              ),
            );
          },
          child: Container(
            width: w * 0.90,
            height: 52,
            decoration: BoxDecoration(
              color: isTeamChat
                  ? const Color(0xFFC0C0C0).withOpacity(0.2)
                  : Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isTeamChat
                    ? const Color(0xFFC0C0C0)
                    : Colors.white.withOpacity(0.16),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                if (showTeamToggle) ...[
                  GestureDetector(
                    onTap: () {
                      onToggleTeam?.call(); // Toggle specific button
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isTeamChat
                            ? const Color(0xFFC0C0C0)
                            : Colors.deepPurple,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        isTeamChat ? "TEAM" : "ALL",
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isTeamChat ? Colors.black : Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    isTeamChat ? 'Message Team...' : 'Tap to game chat...',
                    style: TextStyle(
                        color: isTeamChat
                            ? const Color(0xFFC0C0C0)
                            : Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                ),
                const Icon(Icons.emoji_emotions_outlined,
                    color: Colors.white70, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
