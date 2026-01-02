import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../theme/app_theme.dart';

/// Displays the user's current gem balance with real-time Firebase sync
class GemBalanceWidget extends StatefulWidget {
  final double? fontSize;
  final Color? backgroundColor;
  final Color? borderColor;

  const GemBalanceWidget({
    super.key,
    this.fontSize,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  State<GemBalanceWidget> createState() => _GemBalanceWidgetState();
}

class _GemBalanceWidgetState extends State<GemBalanceWidget> {
  int _gemBalance = 0;
  bool _isLoading = true;
  DatabaseReference? _walletRef;

  @override
  void initState() {
    super.initState();
    _setupGemListener();
  }

  void _setupGemListener() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }

    // Listen to users/{uid}/wallet/gems
    _walletRef = FirebaseDatabase.instance.ref('users/$uid/wallet/gems');

    _walletRef!.onValue.listen((event) {
      if (event.snapshot.value != null) {
        final value = event.snapshot.value;
        setState(() {
          _gemBalance =
              (value is int) ? value : ((value is double) ? value.toInt() : 0);
          _isLoading = false;
        });
      } else {
        // If no value exists, default to 0
        setState(() {
          _gemBalance = 0;
          _isLoading = false;
        });
      }
    }, onError: (error) {
      debugPrint('Error reading gem balance: $error');
      setState(() => _isLoading = false);
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  String _formatNumber(int amount) {
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
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.diamond,
            size: 16,
            color: AppTheme.neonBlue,
          ),
          const SizedBox(width: 6),
          _isLoading
              ? const SizedBox(
                  width: 30,
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
                  _formatNumber(_gemBalance),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: widget.fontSize ?? 13,
                  ),
                ),
          // Optional "Add" button if we implement IAP later
          /*
           const SizedBox(width: 4),
           Container(
             width: 16,
             height: 16,
             decoration: const BoxDecoration(
               color: AppColors.neonBlue, 
               shape: BoxShape.circle
             ),
             child: const Icon(Icons.add, size: 12, color: Colors.white)
           )
           */
        ],
      ),
    );
  }
}
