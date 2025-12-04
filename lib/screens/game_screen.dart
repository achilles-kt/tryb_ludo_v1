import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../game/ludo_game.dart';
import '../widgets/game/game_top_bar.dart';
import '../widgets/game/game_chat_pill.dart';
import '../widgets/game/dice_overlay.dart';
import '../widgets/game/players_overlay.dart';
import '../widgets/game/end_game_overlay.dart';

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

class _GameScreenState extends State<GameScreen> {
  late final LudoGame _game;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;

    _game = LudoGame(
      gameId: widget.gameId,
      tableId: widget.tableId,
      localUid: uid,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1) Top bar (like HTML top-bar)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(child: GameTopBar(game: _game)),
          ),

          // 2) Game area
          Positioned.fill(
            top: 60, // leave space for top bar
            bottom: 80, // leave space for bottom chat pill
            child: Center(
              child: GameWidget(
                game: _game,
                overlayBuilderMap: {
                  'diceOverlay': (ctx, game) =>
                      DiceOverlay(game: game as LudoGame),
                  'playersOverlay': (ctx, game) =>
                      PlayersOverlay(game: game as LudoGame),
                  'endOverlay': (ctx, game) =>
                      EndGameOverlay(game: game as LudoGame),
                },
                initialActiveOverlays: const [
                  'diceOverlay',
                  'playersOverlay',
                  'endOverlay',
                ],
              ),
            ),
          ),

          // 3) Bottom chat pill (shared with lobby)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(child: GameChatPill(game: _game)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // _game.onRemove(); // Flame handles this? Or we should call it?
    // Usually GameWidget handles game lifecycle, but we can manually clean up if needed.
    // LudoGame.onRemove is called by Flame when the game is removed from the widget tree.
    super.dispose();
  }
}
