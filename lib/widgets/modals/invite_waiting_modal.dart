import 'package:flutter/material.dart';

import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import '../../services/invite_service.dart';

class InviteWaitingModal extends StatefulWidget {
  final String inviteId;
  final bool isHost; // To differentiate title/messages if needed

  const InviteWaitingModal({
    super.key,
    required this.inviteId,
    this.isHost = false,
  });

  @override
  _InviteWaitingModalState createState() => _InviteWaitingModalState();
}

class _InviteWaitingModalState extends State<InviteWaitingModal> {
  final InviteService _inviteService = InviteService();
  StreamSubscription<DatabaseEvent>? _inviteSub;
  bool _isLoading = false;
  bool _isError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    _inviteSub = _inviteService.watchInvite(widget.inviteId).listen((event) {
      if (!event.snapshot.exists) {
        // Deleted?
        if (mounted) {
          setState(() {
            _isError = true;
            _errorMessage = "Invite no longer exists.";
          });
        }
        return;
      }

      final data = event.snapshot.value as Map;
      final status = data['status'];

      if (status == 'accepted') {
        // Paired!
        final gameId = data['gameId'];
        final tableId = data['tableId'];
        if (gameId != null && tableId != null) {
          if (mounted) {
            Navigator.of(context)
                .pop({'accepted': true, 'gameId': gameId, 'tableId': tableId});
          }
        }
      } else if (status == 'rejected') {
        if (mounted) {
          setState(() {
            _isError = true;
            _errorMessage = "Friend declined the invite.";
          });
        }
      } else if (status == 'cancelled') {
        // Should only happen if I cancelled it? Or if host somehow cancelled?
        if (mounted) {
          setState(() {
            _isError = true;
            _errorMessage = "Invite cancelled.";
          });
        }
      } else if (status == 'failed_funds') {
        if (mounted) {
          setState(() {
            _isError = true;
            _errorMessage = "Match failed (Insufficient Funds).";
          });
        }
      }
    });
  }

  Future<void> _cancelInvite() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await _inviteService.cancelInvite(widget.inviteId);
      // Wait for stream update or just pop
      if (mounted) Navigator.of(context).pop({'cancelled': true});
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isError = true;
          _errorMessage = "Failed to cancel: $e";
        });
      }
    }
  }

  @override
  void dispose() {
    _inviteSub?.cancel();
    super.dispose();
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
                    widget.isHost
                        ? "Waiting for Friend"
                        : "Requesting to Join...",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                const SizedBox(height: 20),
                if (_isError)
                  Column(
                    children: [
                      Icon(Icons.error_outline,
                          size: 40, color: Colors.redAccent),
                      const SizedBox(height: 10),
                      Text(_errorMessage ?? "Unknown Error",
                          style: TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white24),
                        child: const Text("Close"),
                      )
                    ],
                  )
                else
                  Column(
                    children: [
                      CircularProgressIndicator(color: Colors.amber),
                      const SizedBox(height: 20),
                      Text("Notifying friend...",
                          style: TextStyle(color: Colors.white54)),
                      const SizedBox(height: 30),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _cancelInvite,
                        icon: Icon(Icons.close),
                        label: Text("Cancel"),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent),
                      )
                    ],
                  )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
