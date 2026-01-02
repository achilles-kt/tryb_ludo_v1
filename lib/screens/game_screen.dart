import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/game/ludo_board_widget.dart';
import '../game/ludo_game.dart';
import '../widgets/game/end_game_overlay.dart';
import '../state/game_state.dart';
import '../widgets/game/game_player_profile.dart';

import '../widgets/game/chat_overlay.dart';
import '../widgets/game/dice_sprite_widget.dart'; // Sprite Dice
import '../controllers/game_controller.dart'; // NEW
import '../services/conversion_service.dart'; // Import
import '../widgets/game/forfeit_dialog.dart';
import '../widgets/game/game_top_bar.dart';
import '../widgets/game/game_bottom_controls.dart';

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
  late GameController controller; // NEW
  Timer? _timer;

  // Track active widgets
  // Chat logic moved to ChatOverlay
  bool _isTeamChat = false;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

    // 1. Initialize Controller
    controller = GameController();
    controller.init(widget.gameId, uid);

    // 2. Listen for completion
    controller.onGameCompleted = (winnerUid) {
      if (!_hasShownEndScreen) {
        _hasShownEndScreen = true;
        final isWin = (winnerUid == uid);
        _showEndScreen(isWin ? GameResult.win : GameResult.loss);
      }
    };

    // 3. Create Game with Controller
    game = LudoGame(
      gameId: widget.gameId,
      tableId: widget.tableId,
      localUid: uid,
      controller: controller,
      // onMoveCompleted: _refreshUI, // Optional now, we can listen to controller
      // onGameOver: _showEndScreen, // Handled by controller callback above
    );

    debugPrint('Game Screen Open and visible | Success | $uid');

    // Listen to generic state changes to refresh GameScreen UI (Avatars, etc)
    controller.gameState.addListener(_refreshUI);

    // Refresh UI periodically for timer animation/game loop sync (keep for visual smoothness if needed)
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    controller.gameState.removeListener(_refreshUI);
    controller.dispose(); // Dispose Controller
    super.dispose();
  }

  bool _hasShownEndScreen = false;

  void _refreshUI() {
    if (mounted) setState(() {});

    // Check if I have been marked as left (Forfeit 4P or 2P)
    // Access state via controller now
    if (!_hasShownEndScreen && controller.gameState.value.players.isNotEmpty) {
      final myData = controller
          .gameState.value.players[controller.gameState.value.localPlayerIndex];
      // Wait, localPlayerIndex is an INT index. We need UID lookup or map access.
      // Controller state has players Map<String, dynamic>.
      // We need local UID.
      final localUid = FirebaseAuth.instance.currentUser?.uid;
      if (localUid != null) {
        final myData = controller.gameState.value.players[localUid];
        if (myData != null) {
          final status = myData['status'];
          if (status == 'left' || status == 'kicked') {
            _hasShownEndScreen = true;
            // Trigger Loss Screen
            _showEndScreen(GameResult.loss);
          }
        }
      }
    }
  }

  Future<void> _showEndScreen(GameResult result) async {
    // Activity Stream: Log Game Result
    // Activity Stream: Log Game Result
    if (result == GameResult.win) {
      final winnerUid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      // Helper to get name
      String getName(String id) =>
          controller.gameState.value.players[id]?['name'] ?? 'Player';
      final winnerName = getName(winnerUid);

      controller.logGameResult(winnerUid, winnerName, true);
    }

    // Update Game Notifier so Overlay can render
    game.gameEndNotifier.value = GameEndState(
      isWin: result == GameResult.win,
      rewardText:
          result == GameResult.win ? "+500 Gold" : "Better luck next time!",
    );

    await showDialog(
      // Await
      context: context,
      barrierDismissible: false,
      builder: (_) => EndGameOverlay(game: game),
    );

    // Trigger Nudge Check after game
    if (mounted) {
      await ConversionService.instance.checkGameCompletion(context);
    }
  }

  Future<void> _handleForfeit() async {
    // 1. Show Confirmation Dialog
    // Determine context (Team/Solo) for message
    final meta = game.getPlayerMeta(PlayerSpot.bottomLeft); // Me
    final isTeam = meta?.isTeam ?? false;
    // We haven't fully implemented teammate status check in UI yet,
    // so we'll just pass generic isTeamMode for specific text if needed.
    // Ideally we check if teammate left, but for MVP just isTeamMode is enough warning.

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ForfeitDialog(isTeamMode: isTeam),
    );

    if (confirm != true) return;

    // 2. Call Backend
    if (!mounted) return;

    // 2. Instant UI Update (Optimistic)
    // We do not wait for server. We assume success to unblock the user.
    if (!mounted) return;

    if (!_hasShownEndScreen) {
      _hasShownEndScreen = true;
      _showEndScreen(GameResult.loss);
    }

    // 3. Fire-and-Forget Backend Call
    // 3. Fire-and-Forget Backend Call
    controller.forfeitGame();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _handleForfeit();
      },
      child: Scaffold(
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

              // Calculate Safe Area
              final padding = MediaQuery.of(context).padding;
              final safeTop = padding.top;
              final safeBottom = padding.bottom;

              // Estimated UI Heights (TopBar + Margins, BottomControls + Margins)
              const topBarHeight = 60.0;
              const bottomControlsHeight = 80.0;

              // Avatar Space needed ABOVE and BELOW the board
              // Avatar Widget is approx 80px tall. Margin is 48px.
              // Total reserve per side: ~128px.
              // We'll use 130.0 for safety.
              const avatarReservePerSide = 130.0;

              final topInterface = safeTop + topBarHeight;
              final bottomInterface = safeBottom + bottomControlsHeight;

              // Available vertical space for the board
              // MUST subtract avatar space so they don't get pushed into UI/offscreen
              final usableHeight = screenH -
                  topInterface -
                  bottomInterface -
                  (avatarReservePerSide * 2);

              // Board Size: 98% width (increased from 90% to compensate for camera zoom)
              // but still clamped to usable height
              final boardSize = (screenW * 0.98).clamp(0.0, usableHeight);

              // Center Vertically in the Usable Space
              // The "Usable Space" here is the area between TopUI and BottomUI.
              // The Board + Avatars must be centered there.

              final fullAvailableHeight = screenH -
                  topInterface -
                  bottomInterface; // Space between headers
              // emptySpace is how much "air" is left after Board fits
              final emptySpace = fullAvailableHeight - boardSize;

              // Board Top is absolute position from top of screen
              // We Center it in the Full Available Height
              final boardTop = topInterface + (emptySpace / 2);

              final boardLeft = (screenW - boardSize) / 2;

              return Stack(
                children: [
                  // ---------------- TOP BAR ----------------
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: const GameTopBar(),
                  ),

                  // ---------------- BOARD (FLAME) ----------------
                  LudoBoardWidget(
                    game: game,
                    boardSize: boardSize,
                    top: boardTop,
                    left: boardLeft,
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
                    child: GameBottomControls(
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

        // Fix: Ignore interactions when not waiting for roll
        final canTap = isYourTurn && phase == TurnPhase.waitingRoll;

        return AnimatedPositioned(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          left: targetLeft,
          top: targetTop,
          width: targetSize,
          height: targetSize,
          child: IgnorePointer(
            ignoring: !canTap,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                if (canTap) {
                  game.rollDice();
                }
              },
              child: DiceSpriteWidget(
                controller: game.controller,
                size: targetSize,
                timeLeft: _calculateTimeLeft(state),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatarAtVisualSeat(BuildContext context, int visualSeat,
      double boardLeft, double boardTop, double boardSize, LudoGame game) {
    final meta = game.getPlayerMetaByVisualSeat(visualSeat);
    if (meta == null) {
      // debugPrint("VisualSeat $visualSeat: Meta is NULL");
      return const SizedBox.shrink();
    }
    // debugPrint("VisualSeat $visualSeat: ${meta.name} (${meta.uid}) Team:${meta.isTeam}");

    double? top, left, right;

    // Position Logic
    const double verticalMargin = 48.0; // Symmetrical margin

    switch (visualSeat) {
      case 0: // Bottom-Left (Me)
        top = boardTop + boardSize + verticalMargin;
        left = 16;
        break;
      case 1: // Top-Left
        top = boardTop - 50 - verticalMargin;
        left = 16;
        break;
      case 2: // Top-Right (Opponent or Teammate)
        top = boardTop - 50 - verticalMargin;
        right = 16;
        break;
      case 3: // Bottom-Right
        top = boardTop + boardSize + verticalMargin;
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
              level: meta.level,
              city: meta.city,
              isMe: meta.isYou,
              isTeammate: meta.isTeam,
              isTurn: activeTurn,
              playerColor: meta.playerColor,
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
