import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_logger.dart';
import '../utils/firestore_batch_utils.dart';
import 'firebase_service.dart';

/// Reconciles the VERIFIED FirebaseAuth email into Firestore: the raw
/// address into the owner-only `users/{uid}.email`, and the MASKED author
/// label into the community-readable `noise_readings.userEmail` (sec-2).
///
/// Invariant enforced (settings-9/flow6-06): Firestore identity fields are
/// only ever written FROM the Auth email — never from unverified form
/// input. `verifyBeforeUpdateEmail` changes the Auth email only after the
/// user clicks the verification link (which also ends the session), so
/// the reliable propagation point is the next app-shell mount after
/// sign-in, which is when this service runs.
class ProfileSyncService {
  static final ProfileSyncService _instance = ProfileSyncService._internal();
  factory ProfileSyncService() => _instance;
  ProfileSyncService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// `'<uid>:<email>'` of the last successful (or already-consistent)
  /// reconcile, so repeated MainAppShell mounts in one session no-op but
  /// an account switch or a fresh email change reconciles again.
  String? _lastReconciled;

  /// Idempotent and safe to fire-and-forget on every MainAppShell mount.
  /// No-ops when signed out, already consistent, or already run for this
  /// uid+email pair this session. Never throws.
  Future<void> reconcileUserEmail() async {
    try {
      final user = _auth.currentUser;
      final authEmail = user?.email;
      if (user == null || authEmail == null) return;

      final key = '${user.uid}:$authEmail';
      if (_lastReconciled == key) return;

      final userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      final storedEmail = userDoc.data()?['email'] as String?;
      if (storedEmail == authEmail) {
        _lastReconciled = key;
        return;
      }

      AppLogger.info(
        '[ProfileSync] users/{uid}.email differs from verified Auth email. '
        'Propagating (settings-9/flow6-06)...',
      );

      await _firestore.collection('users').doc(user.uid).set({
        'email': authEmail,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedAtClient': DateTime.now(), // Fallback timestamp
      }, SetOptions(merge: true));

      // Equality-only query (userId ==) — no composite index involved.
      // Chunked commits per arch-4/flow6-05.
      final snapshot = await _firestore
          .collection('noise_readings')
          .where('userId', isEqualTo: user.uid)
          .get();

      // sec-2: noise_readings is readable by every signed-in user
      // (firestore.rules), so userEmail carries the MASKED author label —
      // never the raw address. Writing authEmail verbatim here would
      // re-expose the whole history on every email-change verification.
      final authorDisplay = FirebaseService.authorLabel(
        displayName: user.displayName,
        email: authEmail,
      );

      final updated = await FirestoreBatchUtils.applyInChunks(
        _firestore,
        snapshot.docs.map((doc) => doc.reference).toList(),
        (batch, ref) => batch.update(ref, {'userEmail': authorDisplay}),
      );

      AppLogger.info(
        '[ProfileSync] Propagated verified email to $updated noise_readings docs',
      );
      _lastReconciled = key;
    } catch (e) {
      // Never crash startup; a failed reconcile retries on the next
      // MainAppShell mount because _lastReconciled was not set.
      AppLogger.error('[ProfileSync] Email reconciliation failed', e);
    }
  }
}
