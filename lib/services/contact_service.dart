import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fast_contacts/fast_contacts.dart';
import 'package:flutter/foundation.dart';

class ContactService {
  static final ContactService instance = ContactService._();
  ContactService._();

  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<bool> requestPermission() async {
    var status = await Permission.contacts.status;
    if (!status.isGranted) {
      status = await Permission.contacts.request();
    }
    return status.isGranted;
  }

  Future<void> syncContacts() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // 1. Fetch Local Contacts
      final contacts = await FastContacts.getAllContacts();
      debugPrint("ContactService: Found ${contacts.length} local contacts");

      final localHashes = <String, String>{}; // Hash -> DISPLAY_NAME

      for (var contact in contacts) {
        for (var phone in contact.phones) {
          final clean = phone.number.replaceAll(RegExp(r'\D'), '');
          String target = clean;
          if (clean.length >= 10) {
            target = clean.substring(clean.length - 10);
          }
          if (target.isNotEmpty) {
            final bytes = utf8.encode(target);
            final hash = sha256.convert(bytes).toString();
            // Map hash to name so if match is found, we know who it is (optional)
            localHashes[hash] = contact.displayName;
          }
        }
      }
      debugPrint(
          "ContactService: Extracted ${localHashes.length} unique phone hashes");

      if (localHashes.isEmpty) return;

      // 2. Call Cloud Function with Hashes
      final hashesList = localHashes.keys.toList();
      debugPrint(
          "ContactService: Sending ${hashesList.length} hashes to server...");

      final result =
          await FirebaseFunctions.instance.httpsCallable('syncContacts').call({
        'hashes': hashesList,
      });

      final data = result.data as Map<dynamic, dynamic>;
      final matches = data['matches'] as List<dynamic>?;

      if (matches == null || matches.isEmpty) {
        debugPrint("ContactService: No matches found.");
        return;
      }

      debugPrint("ContactService: Server processed ${matches.length} matches!");

      // Mark as synced
      await _db.child('users/${user.uid}/flags/contactsSynced').set(true);
    } catch (e) {
      debugPrint("ContactService: Sync Error: $e");
    }
  }

  Future<void> trySilentSync() async {
    final status = await Permission.contacts.status;
    if (status.isGranted) {
      debugPrint("ContactService: Permission granted. Running silent sync...");
      // Run unawaited or awaited? Awaited but doesn't block UI if called from async init
      await syncContacts();
    } else {
      debugPrint(
          "ContactService: Permission not granted. Skipping silent sync.");
    }
  }
}
