import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../theme/app_theme.dart';

/// Displays the user's current gold balance with real-time Firebase sync
class GoldBalanceWidget extends StatefulWidget {
  final double? fontSize;
  final Color? backgroundColor;
  final Color? borderColor;

  const GoldBalanceWidget({
    super.key,
    this.fontSize,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  State<GoldBalanceWidget> createState() => _GoldBalanceWidgetState();
}

class _GoldBalanceWidgetState extends State<GoldBalanceWidget> {
  int _goldBalance = 0;
  bool _isLoading = true;
  DatabaseReference? _walletRef;

  @override
  void initState() {
    super.initState();
    _setupGoldListener();
  }

  void _setupGoldListener() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }

    // Listen to users/{uid}/wallet/gold
    _walletRef = FirebaseDatabase.instance.ref('users/$uid/wallet/gold');

    _walletRef!.onValue.listen((event) {
      if (event.snapshot.value != null) {
        final value = event.snapshot.value;
        setState(() {
          _goldBalance =
              (value is int) ? value : ((value is double) ? value.toInt() : 0);
          _isLoading = false;
        });
      } else {
        // If no value exists, default to 0
        setState(() {
          _goldBalance = 0;
          _isLoading = false;
        });
      }
    }, onError: (error) {
      debugPrint('Error reading gold balance: $error');
      setState(() => _isLoading = false);
    });
  }

  @override
  void dispose() {
    // Firebase listener is automatically cleaned up
    super.dispose();
  }

  String _formatGold(int amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}k';
    }
    return amount.toString();
  }

  @override
  Widget build(BuildContext context) {
    // ... (inside build)
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54, // Darker pill bg
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1), // Glass border
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.monetization_on,
            size: 16,
            color: AppTheme.gold,
          ),
          const SizedBox(width: 6),
          _isLoading
              ? const SizedBox(
                  width: 40,
                  height: 13,
                  child: Center(
                    child: SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                )
              : Text(
                  _formatGold(_goldBalance),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: widget.fontSize ?? 13,
                  ),
                ),
        ],
      ),
    );
  }
}
