import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../game/ludo_game.dart';
import '../../state/game_state.dart';
import '../dice_widget.dart';

class DiceOverlay extends StatefulWidget {
  final LudoGame game;
  const DiceOverlay({super.key, required this.game});

  @override
  State<DiceOverlay> createState() => _DiceOverlayState();
}

class _DiceOverlayState extends State<DiceOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _rollCtrl;
  double _timerProgress = 1.0; // 1.0 -> full, 0 -> empty

  @override
  void initState() {
    super.initState();
    _rollCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Restart timer when turn changes
    widget.game.turnOwnerNotifier.addListener(_restartTimer);

    // Listen for roll events
    widget.game.isRollingNotifier.addListener(_onRollingChanged);

    _restartTimer();
  }

  @override
  void dispose() {
    _rollCtrl.dispose();
    widget.game.turnOwnerNotifier.removeListener(_restartTimer);
    widget.game.isRollingNotifier.removeListener(_onRollingChanged);
    super.dispose();
  }

  void _onRollingChanged() {
    if (widget.game.isRollingNotifier.value) {
      _rollCtrl.forward(from: 0);
    }
  }

  void _restartTimer() {
    if (!mounted) return;
    setState(() => _timerProgress = 1.0);
    // simple linear drain over 10 seconds (matching backend timeout + buffer)
    const seconds = 10;
    final start = DateTime.now();

    // Use a periodic timer instead of doWhile for cleaner cleanup
    // But doWhile is fine if we check mounted
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return false;

      // Stop if turn changed (handled by listener, but good to check)
      // Actually listener restarts it, so this loop should stop naturally?
      // No, we need to cancel the previous loop if we could.
      // But since we just update state, multiple loops fighting is bad.
      // Let's use a simple approach: check if the turn owner is still the same?
      // Or just rely on the fact that we reset progress.

      final elapsed = DateTime.now().difference(start).inMilliseconds / 1000.0;
      final p = (seconds - elapsed) / seconds;

      if (p <= 0) {
        setState(() => _timerProgress = 0);
        return false;
      }
      setState(() => _timerProgress = p.clamp(0.0, 1.0));
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // We need the current phase + whose turn it is
    final gameState = widget.game.state; // uses your GameState getter
    final phase = gameState.turnPhase; // TurnPhase enum
    final isMyTurn =
        widget.game.currentTurnUidNotifier.value == widget.game.localUid;

    return ValueListenableBuilder<TurnOwner>(
      valueListenable: widget.game.turnOwnerNotifier,
      builder: (ctx, owner, _) {
        // Position depends on owner AND phase (center while rolling)
        final pos = _posForOwnerAndPhase(owner, phase, context);

        // Dice is tappable only if:
        // - it's my turn
        // - phase is waitingRoll (hasn't rolled yet)
        // - some time is left on the timer
        final canTapDice =
            isMyTurn && phase == TurnPhase.waitingRoll && _timerProgress > 0.0;

        // Debug logs for tap conditions
        if (isMyTurn) {
          // Only log if it's my turn to avoid spam
          debugPrint(
              '🎲 DiceOverlay Build: isMyTurn=$isMyTurn, phase=$phase, timer=$_timerProgress, canTap=$canTapDice');
        }

        return AnimatedPositioned(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutBack,
          left: pos.dx,
          top: pos.dy,
          child: GestureDetector(
            onTap: canTapDice
                ? () async {
                    final currentUser = FirebaseAuth.instance.currentUser;
                    debugPrint(
                        '🎲 Tapping dice. Current User: ${currentUser?.uid}');
                    if (currentUser == null) {
                      debugPrint('❌ Cannot roll: User not signed in.');
                      return;
                    }
                    try {
                      await widget.game.rollDice();
                    } catch (e) {
                      debugPrint('❌ Error calling rollDice: $e');
                    }
                  }
                : null, // disables taps when not allowed
            child: _buildDiceWithTimer(phase, isMyTurn),
          ),
        );
      },
    );
  }

  Offset _posForOwnerAndPhase(
    TurnOwner owner,
    TurnPhase phase,
    BuildContext ctx,
  ) {
    final size = MediaQuery.of(ctx).size;

    // While rolling, dice goes to center of screen (approx center of board)
    if (phase == TurnPhase.rollingAnim) {
      const diceSize = 70.0;
      return Offset(
        (size.width - diceSize) / 2,
        (size.height - diceSize) / 2,
      );
    }

    // In all other phases, dice sits near the current turn owner's profile
    return _posForOwner(owner, ctx);
  }

  Offset _posForOwner(TurnOwner owner, BuildContext ctx) {
    final size = MediaQuery.of(ctx).size;
    final w = size.width;
    final h = size.height;
    const dxOffset = 80.0;
    const dyOffset = 180.0; // Adjusted to not overlap with bottom pill

    return switch (owner) {
      TurnOwner.bottomLeft => Offset(40, h - dyOffset),
      TurnOwner.topLeft => const Offset(40, 120),
      TurnOwner.topRight => Offset(w - dxOffset, 120),
      TurnOwner.bottomRight => Offset(w - dxOffset, h - dyOffset),
    };
  }

  Widget _buildDiceWithTimer(TurnPhase phase, bool isMyTurn) {
    return ValueListenableBuilder<int>(
      valueListenable: widget.game.diceValueNotifier,
      builder: (ctx, v, _) {
        // Dice should look blank while we are in waitingRoll,
        // regardless of previous value.
        final isBlank = phase == TurnPhase.waitingRoll;

        return DiceWidget(
          value: v,
          timeLeft: _timerProgress,
          size: 70,
          isBlank: isBlank,
          onTap: null, // tap handled by outer GestureDetector
        );
      },
    );
  }
}
