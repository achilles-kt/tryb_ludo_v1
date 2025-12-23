// lib/widgets/waiting_match_modal.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';

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
            if (mounted)
              setState(() => _statusText = 'Queued — waiting for opponent');
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

  Widget _buildBody() {
    if (_isError) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Icon(Icons.error_outline, size: 36, color: Colors.redAccent),
          const SizedBox(height: 12),
          Text(_errorMessage ?? 'Unknown error', textAlign: TextAlign.center),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: () => Navigator.of(context)
                .pop({'cancelled': true, 'error': _errorMessage}),
            child: const Text('Close'),
          ),
          const SizedBox(height: 8),
        ],
      );
    }

    if (widget.mode == '4p') {
      return _build4PBody();
    }

    return _build2PBody();
  }

  // ----------------- 2P Layout -----------------
  Widget _build2PBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _avatar('ME'),
            const SizedBox(width: 12),
            _vsText(),
            const SizedBox(width: 12),
            _avatar('?', isPlaceholder: true),
          ],
        ),
        _statusSection(),
      ],
    );
  }

  // ----------------- 4P Layout -----------------
  Widget _build4PBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Left Team (Me + ?)
            Column(
              children: [
                Row(children: [
                  _avatar('ME', size: 24),
                  const SizedBox(width: 4),
                  _hasTeammate
                      ? _avatar(
                          _teammateName != null && _teammateName!.isNotEmpty
                              ? _teammateName![0]
                              : 'P2',
                          size: 24)
                      : _spinnerAvatar(size: 24)
                ]),
                const SizedBox(height: 4),
                Text(_teammateName ?? "My Team",
                    style: TextStyle(fontSize: 10, color: Colors.white54))
              ],
            ),

            const SizedBox(width: 12),
            _vsText(),
            const SizedBox(width: 12),

            // Right Team (Opponents)
            Column(
              children: [
                Row(children: [
                  _avatar('?', size: 24, isPlaceholder: true),
                  const SizedBox(width: 4),
                  _avatar('?', size: 24, isPlaceholder: true),
                ]),
                const SizedBox(height: 4),
                const Text("Opponents",
                    style: TextStyle(fontSize: 10, color: Colors.white54))
              ],
            ),
          ],
        ),
        _statusSection(),
      ],
    );
  }

  Widget _statusSection() {
    return Column(children: [
      const SizedBox(height: 16),
      Text(_statusText,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white70)),
      const SizedBox(height: 16),
      if (_isLoading)
        const SizedBox(
          height: 30,
          width: 30,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      else
        const SizedBox(height: 30),
      const SizedBox(height: 20),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _leaveQueue,
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Cancel'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
          ),
        ],
      ),
    ]);
  }

  Widget _vsText() {
    return Column(children: const [
      Text('VS',
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white54,
              fontStyle: FontStyle.italic)),
    ]);
  }

  Widget _avatar(String label, {double size = 28, bool isPlaceholder = false}) {
    return CircleAvatar(
      radius: size,
      backgroundColor: isPlaceholder ? Colors.white10 : Colors.deepPurple,
      child: Text(label,
          style: TextStyle(
              fontSize: size * 0.6,
              fontWeight: FontWeight.bold,
              color: Colors.white)),
    );
  }

  Widget _spinnerAvatar({double size = 28}) {
    return Container(
        width: size * 2,
        height: size * 2,
        decoration:
            BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
        child: const Padding(
            padding: EdgeInsets.all(12),
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white30)));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Material(
          color: const Color(0xFF0B0C10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    widget.mode == '4p'
                        ? 'Team Matchmaking'
                        : 'Finding a Match',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                const SizedBox(height: 8),
                _buildBody(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
