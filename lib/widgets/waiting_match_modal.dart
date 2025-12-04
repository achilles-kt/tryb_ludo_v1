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

  const WaitingMatchModal({
    super.key,
    required this.entryFee,
    this.onPaired,
    this.mockMode = false,
    this.mockDelay = const Duration(seconds: 4),
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

  @override
  void initState() {
    super.initState();
    if (widget.mockMode) {
      // helpful for UI dev without backend
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
      setState(() {
        _isLoading = true;
        _statusText = 'Joining queue...';
      });

      final callable = _functions.httpsCallable('join2PQueue');
      await callable.call(<String, dynamic>{'entryFee': widget.entryFee});

      // subscribe to userQueueStatus/{uid} to get status updates
      _subscribeToStatus();
      setState(() {
        _statusText = 'Waiting for opponent...';
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
        if (status == 'queued') {
          setState(() {
            _statusText = 'Queued — waiting for opponent';
          });
        } else if (status == 'paired') {
          setState(() {
            _statusText = 'Matched! Preparing game...';
          });
          final tableId = v['tableId']?.toString();
          final gameId = v['gameId']?.toString();
          _onPaired(tableId, gameId);
        } else if (status == 'insufficient_funds') {
          setState(() {
            _isError = true;
            _errorMessage = 'Insufficient funds to join this table.';
          });
        } else if (status == 'left') {
          final reason = v['reason']?.toString();
          setState(() {
            _isError = true;
            _errorMessage = reason == 'timeout'
                ? 'Matchmaking timed out. Please try again.'
                : 'You left the queue.';
          });
        }
      }
    }, onError: (err) {
      setState(() {
        _isError = true;
        _errorMessage = err.toString();
      });
    });
  }

  void _onPaired(String? tableId, String? gameId) {
    // guard
    if (tableId == null || gameId == null) {
      setState(() {
        _isError = true;
        _errorMessage = 'Paired but missing table/game ids.';
      });
      return;
    }

    // Cancel subscription before navigating
    _statusSub?.cancel();

    // Pop modal with IDs
    if (mounted) {
      Navigator.of(context).pop({
        'tableId': tableId,
        'gameId': gameId,
      });
    }
  }

  void _onPairedMock() {
    // simulate a pair for UI testing
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
      final callable = _functions.httpsCallable('leaveQueue');
      await callable.call();
      _statusSub?.cancel();
      await _db
          .ref('userQueueStatus/${_uid!}')
          .set({'status': 'left', 'ts': DateTime.now().millisecondsSinceEpoch});
      if (mounted) Navigator.of(context).pop({'cancelled': true});
    } catch (e) {
      // best effort - still close modal
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        _playerAvatarsRow(),
        const SizedBox(height: 12),
        Text(_statusText,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (_isLoading)
          const SizedBox(
            height: 40,
            width: 120,
            child: Center(child: CircularProgressIndicator()),
          )
        else
          const SizedBox(height: 40),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _leaveQueue,
              icon: const Icon(Icons.close),
              label: const Text('Cancel'),
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () {
                      // optionally retry join
                      _startJoinFlow();
                    },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            )
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _playerAvatarsRow() {
    // small UIs with placeholder avatars; can be replaced with real avatars from DB
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _avatar(['A', 'B', 'C', 'D'][DateTime.now().second % 4]),
        const SizedBox(width: 12),
        Column(children: const [
          Text('VS',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white54,
                  fontStyle: FontStyle.italic)),
        ]),
        const SizedBox(width: 12),
        _avatar(['X', 'Y', 'Z'][DateTime.now().second % 3]),
      ],
    );
  }

  Widget _avatar(String label) {
    return CircleAvatar(
      radius: 28,
      backgroundColor: Colors.grey.shade800,
      child: Text(label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
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
                const Text('Finding a Match',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
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
