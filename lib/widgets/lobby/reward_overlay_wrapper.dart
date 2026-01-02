import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:firebase_database/firebase_database.dart';

class RewardOverlayWrapper extends StatefulWidget {
  final Widget child;
  final String? currentUid;

  const RewardOverlayWrapper({super.key, required this.child, this.currentUid});

  @override
  State<RewardOverlayWrapper> createState() => _RewardOverlayWrapperState();
}

class _RewardOverlayWrapperState extends State<RewardOverlayWrapper> {
  @override
  void didUpdateWidget(covariant RewardOverlayWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentUid != oldWidget.currentUid &&
        widget.currentUid != null) {
      _checkRewards();
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.currentUid != null) {
      _checkRewards();
    }
  }

  void _checkRewards() {
    final uid = widget.currentUid;
    if (uid == null) return;

    final ref = FirebaseDatabase.instance.ref('walletTransactions/$uid');

    ref
        .orderByChild('meta/reason')
        .equalTo('initial_rewards')
        .onChildAdded
        .listen((event) {
      final val = event.snapshot.value as Map?;
      if (val != null) {
        final meta = val['meta'] as Map?;
        final seen = meta?['seen'] == true;

        if (!seen) {
          // Show Reward!
          final amount = val['amount'];
          final currency = val['currency'] ?? 'gold';

          if (mounted) {
            _showRewardOverlay(event.snapshot.key!, amount, currency);
          }
        }
      }
    }, onError: (e) {
      print("Rewards check error: $e");
    });
  }

  void _showRewardOverlay(String txnKey, dynamic amount, String currency) {
    if (!mounted) return;

    final uid = widget.currentUid;
    if (uid != null) {
      FirebaseDatabase.instance
          .ref('walletTransactions/$uid/$txnKey/meta/seen')
          .set(true);
    }

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => Dialog(
              backgroundColor: Colors.transparent,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                          gradient: AppTheme.primaryGrad,
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                                color: AppTheme.neonPurple.withOpacity(0.5),
                                blurRadius: 40)
                          ]),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "WELCOME GIFT!",
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 2),
                          ),
                          const SizedBox(height: 20),
                          // Icon
                          Image.asset(
                            currency == 'gems'
                                ? 'assets/imgs/gem.png'
                                : 'assets/imgs/coin.png',
                            width: 80,
                            height: 80,
                            errorBuilder: (c, o, s) => Icon(
                                currency == 'gems'
                                    ? Icons.diamond
                                    : Icons.monetization_on,
                                size: 80,
                                color: Colors.white),
                          ),
                          const SizedBox(height: 12),
                          Text("+$amount ${currency.toUpperCase()}",
                              style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.amberAccent,
                                  shadows: [
                                    Shadow(
                                        color: Colors.black45,
                                        offset: Offset(2, 2),
                                        blurRadius: 4)
                                  ])),
                          const SizedBox(height: 24),
                          ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.purple,
                                  shape: StadiumBorder()),
                              onPressed: () => Navigator.pop(context),
                              child: const Text("AWESOME!"))
                        ],
                      ),
                    ),
                  );
                },
              ),
            ));
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
