// lib/widgets/waiting_match_modal.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../theme/app_theme.dart';
import '../common/glass_container.dart';

typedef OnPairedCallback = void Function({
  required String tableId,
  required String gameId,
});

class WaitingMatchModal extends StatefulWidget {
  final int entryFee;
  final OnPairedCallback? onPaired;
  final bool mockMode; // when true, simulates a pairing for local UI testing
  final Duration mockDelay;
  final String mode; // '2p' or '4p'

  const WaitingMatchModal({
    super.key,
    required this.entryFee,
    this.onPaired,
    this.mockMode = false,
    this.mockDelay = const Duration(seconds: 4),
    this.mode = '2p',
  });

  @override
  State<WaitingMatchModal> createState() => _WaitingMatchModalState();
}

class _WaitingMatchModalState extends State<WaitingMatchModal> {
  final _functions = FirebaseFunctions.instance;
  StreamSubscription<DatabaseEvent>? _statusSub;
  String _statusText = 'Joining queue...';
  bool _isLoading = true;
  bool _isError = false;
  String? _errorMessage;
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  final _db = FirebaseDatabase.instance;

  // 4P Specific State
  bool _hasTeammate = false; // Transition from Solo Queue to Team Queue
  String? _teammateName; // Could fetch this
  // In a real app we'd fetch names. For now we just show "Partner" or "Bot".

  @override
  void initState() {
    super.initState();
    debugPrint('🔍 DEBUG: WaitingMatchModal called for mode: ${widget.mode}');
    if (widget.mockMode) {
      Future.delayed(widget.mockDelay, () {
        _onPairedMock();
      });
    } else {
      _startJoinFlow();
    }
  }

  Future<void> _startJoinFlow() async {
    if (_uid == null) {
      setState(() {
        _isError = true;
        _errorMessage = 'Not signed in. Sign in first.';
        _isLoading = false;
      });
      return;
    }

    try {
      debugPrint(
          'WaitingMatchModal picked | UID: $_uid | Mode: ${widget.mode}');
      setState(() {
        _isLoading = true;
        _statusText = widget.mode == '4p'
            ? 'Looking for a teammate...'
            : 'Joining queue...';
      });

      // Determine correct Cloud Function
      final functionName =
          widget.mode == '4p' ? 'joinSoloQueue' : 'join2PQueue';

      final callable = _functions.httpsCallable(functionName);
      await callable.call(<String, dynamic>{'entryFee': widget.entryFee});

      // subscribe to userQueueStatus/{uid} to get status updates
      _subscribeToStatus();
      setState(() {
        _statusText = widget.mode == '4p'
            ? 'Searching for partner...'
            : 'Waiting for opponent...';
        _isLoading = false;
      });
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _isError = true;
        _errorMessage = e.message ?? e.code;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _subscribeToStatus() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = _db.ref('userQueueStatus/$uid');
    _statusSub = ref.onValue.listen((event) {
      final snap = event.snapshot;
      if (!snap.exists) return;
      final v = snap.value;
      if (v is Map) {
        final status = v['status']?.toString();

        // 4P specific logic
        if (widget.mode == '4p') {
          if (status == 'queued_solo') {
            if (mounted) setState(() => _statusText = 'Finding a teammate...');
          } else if (status == 'queued_team') {
            // Transition to Stage 2
            final teamId = v['teamId'];
            debugPrint(
                '🔍 DEBUG: userQueueStatus update | TeamID: $teamId | Status: queued_team');
            final tName = v['teammateName']?.toString();
            if (mounted) {
              setState(() {
                _hasTeammate = true;
                _teammateName = tName;
                _statusText = 'Team formed! Searching for opponents...';
              });
            }
          }
        } else {
          // 2P Logic
          if (status == 'queued') {
            if (mounted) {
              setState(() => _statusText = 'Queued — waiting for opponent');
            }
          }
        }

        if (status == 'paired') {
          if (mounted) {
            setState(() {
              _statusText = 'Matched! Preparing game...';
            });
          }
          final tableId = v['tableId']?.toString();
          final gameId = v['gameId']?.toString();
          _onPaired(tableId, gameId);
        } else if (status == 'insufficient_funds') {
          if (mounted) {
            setState(() {
              _isError = true;
              _errorMessage = 'Insufficient funds to join this table.';
            });
          }
        } else if (status == 'left') {
          final reason = v['reason']?.toString();
          if (mounted) {
            setState(() {
              _isError = true;
              _errorMessage = reason == 'timeout'
                  ? 'Matchmaking timed out. Please try again.'
                  : reason == 'partner_left'
                      ? 'Your partner left the queue.'
                      : 'You left the queue.';
            });
          }
        }
      }
    }, onError: (err) {
      if (mounted) {
        setState(() {
          _isError = true;
          _errorMessage = err.toString();
        });
      }
    });
  }

  void _onPaired(String? tableId, String? gameId) {
    if (tableId == null || gameId == null) {
      setState(() {
        _isError = true;
        _errorMessage = 'Paired but missing table/game ids.';
      });
      return;
    }
    _statusSub?.cancel();
    if (mounted) {
      Navigator.of(context).pop({
        'tableId': tableId,
        'gameId': gameId,
      });
    }
  }

  void _onPairedMock() {
    _statusSub?.cancel();
    widget.onPaired?.call(tableId: 'mock-table', gameId: 'mock-game');
    Navigator.of(context).pop({'tableId': 'mock-table', 'gameId': 'mock-game'});
  }

  Future<void> _leaveQueue() async {
    setState(() {
      _isLoading = true;
      _statusText = 'Leaving queue...';
    });
    try {
      final callable =
          _functions.httpsCallable('leaveQueue'); // Works for both? Need verify
      // Ideally separate leave function or leaveQueue handles based on user status (which it does via currentQueue path)
      // Assuming existing leaveQueue handles generic removal or we need update.
      // For now assume it works or just client-side detach.
      await callable.call();
      _statusSub?.cancel();
      await _db
          .ref('userQueueStatus/${_uid!}')
          .set({'status': 'left', 'ts': DateTime.now().millisecondsSinceEpoch});
      if (mounted) Navigator.of(context).pop({'cancelled': true});
    } catch (e) {
      _statusSub?.cancel();
      if (mounted) {
        Navigator.of(context).pop({'cancelled': true, 'error': e.toString()});
      }
    }
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(16),
      child: GlassContainer(
        borderRadius: 24,
        padding: const EdgeInsets.all(24),
        border:
            Border.all(color: AppTheme.neonBlue.withOpacity(0.3), width: 1.5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Text(
              widget.mode == '4p' ? 'TEAM MATCHMAKING' : 'FINDING A MATCH',
              style: AppTheme.header.copyWith(fontSize: 20, letterSpacing: 1.2),
            ),
            const SizedBox(height: 24),

            // Body
            _isError
                ? _buildErrorBody()
                : (widget.mode == '4p' ? _build4PBody() : _build2PBody()),

            const SizedBox(height: 32),

            // Status Text
            if (!_isError) _buildStatusSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBody() {
    return Column(
      children: [
        Icon(Icons.error_outline, size: 48, color: AppTheme.neonRed),
        const SizedBox(height: 16),
        Text(_errorMessage ?? 'Unknown error',
            textAlign: TextAlign.center,
            style: AppTheme.text.copyWith(color: Colors.white70)),
        const SizedBox(height: 24),
        _neonButton(
            "CLOSE", () => Navigator.of(context).pop({'cancelled': true})),
      ],
    );
  }

  Widget _buildStatusSection() {
    return Column(
      children: [
        if (_isLoading)
          Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.neonBlue),
                strokeWidth: 2,
              ),
            ),
            SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.neonPurple),
                strokeWidth: 2,
              ),
            ),
          ]),
        const SizedBox(height: 20),
        Text(_statusText,
            textAlign: TextAlign.center,
            style: AppTheme.label
                .copyWith(fontSize: 14, color: AppTheme.neonBlue)),
        const SizedBox(height: 24),
        TextButton(
          onPressed: _leaveQueue,
          child: Text("CANCEL",
              style: AppTheme.label.copyWith(color: Colors.white30)),
        )
      ],
    );
  }

  // 2P Visuals
  Widget _build2PBody() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _avatar('ME'),
        const SizedBox(width: 16),
        const Text("VS",
            style: TextStyle(
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                fontSize: 24,
                color: Colors.white24)),
        const SizedBox(width: 16),
        _avatar('?', isPlaceholder: true),
      ],
    );
  }

  // 4P Visuals
  Widget _build4PBody() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // My Team
        Column(
          children: [
            SizedBox(
              width: 60,
              height: 40,
              child: Stack(
                children: [
                  _avatar('ME', size: 20),
                  Positioned(
                      left: 20,
                      child: _hasTeammate
                          ? _avatar(
                              _teammateName != null && _teammateName!.isNotEmpty
                                  ? _teammateName![0]
                                  : 'P2',
                              size: 20)
                          : _spinnerAvatar(size: 20))
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(_teammateName ?? "Searching...",
                style: AppTheme.label.copyWith(fontSize: 10))
          ],
        ),

        const SizedBox(width: 16),
        const Text("VS",
            style: TextStyle(
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                fontSize: 24,
                color: Colors.white24)),
        const SizedBox(width: 16),

        // Opponents
        Column(
          children: [
            SizedBox(
              width: 60,
              height: 40,
              child: Stack(
                children: [
                  _avatar('?', size: 20, isPlaceholder: true),
                  Positioned(
                      left: 20,
                      child: _avatar('?', size: 20, isPlaceholder: true)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text("Opponents", style: AppTheme.label.copyWith(fontSize: 10))
          ],
        ),
      ],
    );
  }

  Widget _avatar(String label, {double size = 28, bool isPlaceholder = false}) {
    return Container(
      width: size * 2,
      height: size * 2,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isPlaceholder ? Colors.white10 : AppTheme.bgDark,
          border: Border.all(
              color: isPlaceholder ? Colors.white10 : AppTheme.neonBlue,
              width: 2),
          boxShadow: isPlaceholder
              ? null
              : [
                  BoxShadow(
                      color: AppTheme.neonBlue.withOpacity(0.4), blurRadius: 10)
                ]),
      alignment: Alignment.center,
      child: Text(label,
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: size * 0.8)),
    );
  }

  Widget _spinnerAvatar({double size = 28}) {
    return Container(
      width: size * 2,
      height: size * 2,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white10, style: BorderStyle.none),
          color: Colors.white10),
      child: const Padding(
        padding: EdgeInsets.all(10),
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white30),
      ),
    );
  }

  Widget _neonButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
            gradient: AppTheme.primaryGrad,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                  color: AppTheme.neonBlue.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ]),
        child: Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }
}
