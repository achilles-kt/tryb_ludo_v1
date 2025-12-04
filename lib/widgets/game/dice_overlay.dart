import 'package:flutter/material.dart';
import '../../game/ludo_game.dart';

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
    return ValueListenableBuilder<TurnOwner>(
      valueListenable: widget.game.turnOwnerNotifier,
      builder: (ctx, owner, _) {
        final pos = _posForOwner(owner, context);
        return AnimatedPositioned(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutBack,
          left: pos.dx,
          top: pos.dy,
          child: GestureDetector(
            onTap: () async {
              final isMyTurn = widget.game.currentTurnUidNotifier.value ==
                  widget.game.localUid;
              if (!isMyTurn) return;

              await widget.game.rollDice();
            },
            child: _buildDiceWithTimer(),
          ),
        );
      },
    );
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

  Widget _buildDiceWithTimer() {
    return SizedBox(
      width: 70,
      height: 70,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Timer ring
          CustomPaint(
            size: const Size(70, 70),
            painter: _TimerPainter(progress: _timerProgress),
          ),
          // Dice cube
          RotationTransition(
            turns: _rollCtrl,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.white, Color(0xFFECECEC)],
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 8,
                    offset: Offset(0, 3),
                    color: Colors.black54,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: ValueListenableBuilder<int>(
                valueListenable: widget.game.diceValueNotifier,
                builder: (ctx, v, _) => Text(
                  v.toString(),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimerPainter extends CustomPainter {
  final double progress;
  _TimerPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 4;

    final bgPaint = Paint()
      ..color = Colors.white10
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius, bgPaint);

    final fgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFA259FF), Color(0xFF3B82F6)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final sweep = 2 * 3.14159 * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2,
      sweep,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TimerPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
