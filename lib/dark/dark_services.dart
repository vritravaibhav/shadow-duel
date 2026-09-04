import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

/// Firebase, but only for the Dark section: nothing here is touched until
/// the player walks through that door, so the campaign never asks anyone
/// to sign in.
class Dark {
  static bool _init = false;
  static String? initError;

  static bool get ready => _init && initError == null;

  static Future<void> ensureFirebase() async {
    if (_init) return;
    _init = true;
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (e) {
      initError = '$e';
      debugPrint('Firebase unavailable: $e');
    }
  }

  static FirebaseAuth get auth => FirebaseAuth.instance;
  static FirebaseFirestore get db => FirebaseFirestore.instance;
  static User? get user => ready ? auth.currentUser : null;

  // ---- Auth ---------------------------------------------------------------------

  static Future<String?> signIn(String email, String password) async {
    try {
      await auth.signInWithEmailAndPassword(email: email.trim(), password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return _authMessage(e);
    }
  }

  static Future<String?> register(String email, String password) async {
    try {
      await auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return _authMessage(e);
    }
  }

  static Future<String?> guest() async {
    try {
      await auth.signInAnonymously();
      return null;
    } on FirebaseAuthException catch (e) {
      return _authMessage(e);
    }
  }

  static Future<void> signOut() => auth.signOut();

  static String _authMessage(FirebaseAuthException e) => switch (e.code) {
        'invalid-email' => 'That is not an email address.',
        'user-not-found' || 'wrong-password' || 'invalid-credential' => 'Wrong email or password.',
        'email-already-in-use' => 'That email already has an account. Sign in instead.',
        'weak-password' => 'Password needs at least 6 characters.',
        'operation-not-allowed' => 'Sign-in method is switched off in the Firebase console (Authentication → Get started).',
        'network-request-failed' => 'No connection.',
        'configuration-not-found' => 'Authentication is not set up yet: open the Firebase console → Authentication → Get started.',
        _ => e.message ?? e.code,
      };

  // ---- Entitlement --------------------------------------------------------------

  /// Whether [uid] has paid for the Dark. Written server-side only (see
  /// firestore.rules and tool/grant_dark.sh).
  static Stream<bool> entitlement(String uid) => db
      .collection('entitlements')
      .doc(uid)
      .snapshots()
      .map((d) => (d.data()?['dark'] as bool?) ?? false)
      .handleError((_) {});

  // ---- Profile ------------------------------------------------------------------

  static Future<void> saveProfile(String name, String char) async {
    final u = user;
    if (u == null) return;
    await db.collection('profiles').doc(u.uid).set({
      'name': name,
      'char': char,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<(String, String)?> loadProfile() async {
    final u = user;
    if (u == null) return null;
    final d = await db.collection('profiles').doc(u.uid).get();
    final m = d.data();
    if (m == null) return null;
    return (m['name'] as String? ?? '', m['char'] as String? ?? '');
  }
}

/// The purchase hook. There is no store wired yet: the button explains how
/// a tester is let in, and a real IAP / Stripe backend can drop in here by
/// writing `entitlements/{uid}.dark = true` from the server.
class DarkStore {
  static const priceLabel = '\$4.99';

  static Future<String> purchase() async {
    final uid = Dark.user?.uid;
    return 'Purchases are not connected to a store yet.\n'
        'To be let in as a tester, run:\n'
        'tool/grant_dark.sh ${uid ?? '<uid>'}';
  }
}
