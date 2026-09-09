# Implementation Spec — Defect Cluster 03: Account Lifecycle (Delete, Email, Logout)

Target app: `noise_pollution_mapper/` (Flutter + Firebase + Hive).
Execute steps strictly in order. Each step is exactly one commit. `flutter analyze` must be clean after every commit.

All file paths below are relative to the project root `noise_pollution_mapper/`.

**Hard prerequisite for Step 4 only:** `audit/playbook/02_offline_sync_overhaul.md` must be FULLY applied before Step 4 (it adds `OfflineRecording.userId` tagging, the foreign-entry skip in the sync loop, and the `authStateChanges` listener that Step 4 extends). Steps 1–3 have no dependency on cluster 02 and may land before or after it.

**Firestore index note (project convention 1):** NO change in this spec requires a new composite index. The only composite index remains `noise_readings (userId ASC, timestamp DESC)`. Every Firestore query touched or added here is an equality-only `where('userId', isEqualTo: uid)` fetch (no range, no orderBy), which needs no composite index at all. Do NOT add any index and do NOT create a `firestore.indexes.json`.

**Package API verification (pubspec.yaml):** `firebase_auth: ^5.3.3` provides `EmailAuthProvider.credential`, `User.reauthenticateWithCredential`, `User.delete`, `User.verifyBeforeUpdateEmail`, `User.reload`, `FirebaseAuth.authStateChanges()` — all already used elsewhere in this codebase. `cloud_firestore: ^5.5.0` provides `FirebaseFirestore.batch()`, `WriteBatch.update/delete/commit`, `SetOptions(merge: true)`, `FieldValue.serverTimestamp()`, and typed `DocumentReference<Map<String, dynamic>>` (what `QueryDocumentSnapshot.reference` returns). `TimeoutException`, `unawaited`, and `Future.timeout` come from `dart:async` (SDK ^3.10.3). All verified against the installed versions and current code. Never substitute other APIs.

---

## Scope

| Finding IDs | Status | One-line summary |
|---|---|---|
| settings-1 / sec-3 / flow6-01 | CONFIRMED (Critical) | `_deleteAccount` anonymizes ALL readings BEFORE `user.delete()`; a `requires-recent-login` failure destroys the user's history while the account survives (`lib/screens/settings_screen_enhanced.dart:887-904`) |
| arch-4 / flow6-05 | CONFIRMED (High) | Clear History, Delete Account, and profile-email propagation each use ONE unchunked WriteBatch — `commit()` fails outright over 500 docs, i.e. after ~42 min of total recording (`settings_screen_enhanced.dart:887-901`, `:1021-1031`; `lib/screens/edit_profile_screen.dart:127-139`) |
| settings-9 / flow6-06 | CONFIRMED (High) | New email written to `users/{uid}` + every reading immediately, but the Auth email changes only after the verification link is clicked — permanent identity divergence if never verified (`edit_profile_screen.dart:100-139`) |
| flow6-02 | CONFIRMED (E2E audit, `audit/03_E2E_FLOW_AUDIT.md:1868`) | Logout never flushes or guards the offline sync queue; SyncService keeps running with stale identity across account switch |

Full descriptions and verifier evidence: grep `audit/01_BUGS_AND_CORRECTNESS.md` (settings-1), `audit/05_SECURITY_AUDIT.md` (sec-3), `audit/06_ARCHITECTURE_AND_CODE_QUALITY.md` (arch-4), `audit/03_E2E_FLOW_AUDIT.md` (flow6-01, flow6-05, flow6-06, flow6-02) for each ID.

---

## Pre-reading

Open these files completely before touching anything:

1. `lib/screens/settings_screen_enhanced.dart` (1107 lines) — especially `_showChangePassword` (lines 677–825; the re-authentication pattern at lines 766–772 that Step 2 mirrors), `_showDeleteAccountConfirmation` (827–861), `_deleteAccount` (863–959), `_clearHistory` (997–1076).
2. `lib/screens/edit_profile_screen.dart` (447 lines) — `_updateProfile` (45–204), notably the email branch (98–120) and the readings batch (125–141).
3. `lib/widgets/main_app_shell.dart` (59 lines) — `initState` at 22–26; IndexedStack tab order Map=0, Analytics=1, Dashboard=2, History=3, Settings=4.
4. `lib/screens/dashboard_screen.dart` lines 1–24 (imports) and 678–717 (app-bar actions; the logout IconButton at 681–703).
5. `lib/services/sync_service.dart` — IN ITS POST-CLUSTER-02 STATE (after `audit/playbook/02_offline_sync_overhaul.md` Steps 3, 6, 7): the sync loop with the foreign-owner skip, `_onAuthStateChanged`, `_handleBackOnline`, `triggerManualSync`.
6. `lib/utils/app_logger.dart` — `AppLogger.debug/info/warning/error(message, [error])`.
7. `lib/utils/theme_helper.dart` — `getCardColor`, `getTextColor`, `getSecondaryTextColor`, `getPrimaryColor`.

Key facts your edits rely on:

- The change-password flow (settings_screen_enhanced.dart:766–775) already demonstrates the correct sensitive-operation order: build `EmailAuthProvider.credential(email, password)` → `user.reauthenticateWithCredential(credential)` → only then perform the destructive/sensitive call. Step 2 transplants exactly this order into account deletion.
- All three over-500 batch sites fetch with the equality-only query `collection('noise_readings').where('userId', isEqualTo: uid).get()` — index-safe; only the COMMIT side is broken.
- `verifyBeforeUpdateEmail(newEmail)` (edit_profile_screen.dart:100) only sends a link. `FirebaseAuth.currentUser.email` keeps the OLD address until the link is clicked; after verification Firebase typically revokes the session, so the next sign-in is the reliable moment the new email is observable client-side. That is why Step 3 reconciles at MainAppShell mount instead of polling.
- After cluster 02, every queued `OfflineRecording` carries `userId`/`userEmail`, the sync loop skips entries whose `userId != user.uid`, and `SyncService` owns `_authSubscription = _auth.authStateChanges().listen(_onAuthStateChanged)`.
- `SyncService` is a singleton (`factory SyncService() => _instance`); `dashboard_screen.dart` already imports `dart:async` (line 2) and `../utils/app_logger.dart` (line 12), but NOT `sync_service.dart` — Step 4 adds that import.
- The app is email/password-auth only (`login_screen.dart` uses `signInWithEmailAndPassword`; no other providers are wired), so password re-authentication in Step 2 covers every real account.

---

## Steps

### Step 1 — Add a shared chunked-WriteBatch helper and use it for Clear History

**Finding IDs:** arch-4, flow6-05 (part 1 of 3 — the other two call sites are converted in Steps 2 and 3, which rewrite them anyway)
**Goal:** Introduce one reusable helper that commits any number of Firestore write ops in batches of ≤450, and switch `_clearHistory` to it so clearing >500 readings no longer fails outright.

**Files:**
- `lib/utils/firestore_batch_utils.dart` (new)
- `lib/screens/settings_screen_enhanced.dart`
- `test/unit/firestore_batch_utils_test.dart` (new)

**Commit title:** `feat(firestore): add chunked WriteBatch helper and chunk Clear History deletes`

**Exact changes:**

1a. NEW FILE `lib/utils/firestore_batch_utils.dart` — full contents:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_logger.dart';

/// Utilities for committing Firestore writes over arbitrarily many
/// documents without hitting the 500-operation WriteBatch limit
/// (arch-4 / flow6-05). Firestore rejects a batch.commit() whose batch
/// holds more than 500 operations, and the dashboard writes a reading
/// every 5 seconds while recording — so >500 docs is the NORMAL case,
/// not the edge case.
class FirestoreBatchUtils {
  FirestoreBatchUtils._();

  /// Max operations per committed batch. Kept at 450 (not 500) as a
  /// safety margin per the project playbook.
  static const int chunkSize = 450;

  /// Pure helper: split [items] into consecutive sublists of at most
  /// [size] elements, preserving order. Exposed for unit testing.
  static List<List<T>> chunk<T>(List<T> items, {int size = chunkSize}) {
    if (size <= 0) {
      throw ArgumentError.value(size, 'size', 'must be positive');
    }
    final chunks = <List<T>>[];
    for (var start = 0; start < items.length; start += size) {
      final end =
          (start + size < items.length) ? start + size : items.length;
      chunks.add(items.sublist(start, end));
    }
    return chunks;
  }

  /// Apply [applyOp] to every reference in [refs], committing one
  /// WriteBatch per chunk of at most [chunkSize] operations.
  ///
  /// Returns the number of operations committed. Throws on the first
  /// failed commit; chunks committed before the failure STAY committed,
  /// so callers must be idempotent / safe to re-run (deletes and
  /// same-value updates are).
  static Future<int> applyInChunks(
    FirebaseFirestore firestore,
    List<DocumentReference<Map<String, dynamic>>> refs,
    void Function(
      WriteBatch batch,
      DocumentReference<Map<String, dynamic>> ref,
    ) applyOp,
  ) async {
    var committed = 0;
    for (final part in chunk(refs)) {
      final batch = firestore.batch();
      for (final ref in part) {
        applyOp(batch, ref);
      }
      await batch.commit();
      committed += part.length;
      AppLogger.debug(
        '[FirestoreBatchUtils] Committed $committed/${refs.length} batched ops',
      );
    }
    return committed;
  }
}
```

1b. `lib/screens/settings_screen_enhanced.dart` — add the import. Current imports end at line 11.

BEFORE:
```dart
import 'donation_screen.dart';
import '../utils/theme_helper.dart';
```

AFTER:
```dart
import 'donation_screen.dart';
import '../utils/theme_helper.dart';
import '../utils/firestore_batch_utils.dart';
```

1c. Same file — `_clearHistory`, the batch-delete block (lines 1026–1031).

BEFORE:
```dart
      // Delete all readings using batch delete
      final batch = firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
```

AFTER:
```dart
      // Delete all readings in chunked batches (arch-4/flow6-05: a single
      // WriteBatch fails outright over 500 operations)
      await FirestoreBatchUtils.applyInChunks(
        firestore,
        snapshot.docs.map((doc) => doc.reference).toList(),
        (batch, ref) => batch.delete(ref),
      );
```

1d. NEW FILE `test/unit/firestore_batch_utils_test.dart` — full contents:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/utils/firestore_batch_utils.dart';

void main() {
  group('FirestoreBatchUtils.chunk', () {
    test('empty list yields no chunks', () {
      expect(FirestoreBatchUtils.chunk(<int>[]), isEmpty);
    });

    test('list smaller than chunk size yields one chunk', () {
      final chunks = FirestoreBatchUtils.chunk(List.generate(10, (i) => i));
      expect(chunks, hasLength(1));
      expect(chunks.single, hasLength(10));
    });

    test('exactly chunkSize items yield exactly one chunk', () {
      final chunks = FirestoreBatchUtils.chunk(
        List.generate(FirestoreBatchUtils.chunkSize, (i) => i),
      );
      expect(chunks, hasLength(1));
    });

    test('501 items split as 450 + 51 (the flow6-05 failure case)', () {
      final chunks = FirestoreBatchUtils.chunk(List.generate(501, (i) => i));
      expect(chunks, hasLength(2));
      expect(chunks[0], hasLength(450));
      expect(chunks[1], hasLength(51));
    });

    test('1200 items split as 450 + 450 + 300 preserving order', () {
      final items = List.generate(1200, (i) => i);
      final chunks = FirestoreBatchUtils.chunk(items);
      expect(chunks.map((c) => c.length).toList(), [450, 450, 300]);
      expect(chunks.expand((c) => c).toList(), items);
    });

    test('every chunk stays at or under the Firestore 500-op limit', () {
      final chunks = FirestoreBatchUtils.chunk(List.generate(9999, (i) => i));
      for (final c in chunks) {
        expect(c.length, lessThanOrEqualTo(500));
      }
    });

    test('custom size is honored', () {
      final chunks =
          FirestoreBatchUtils.chunk(List.generate(5, (i) => i), size: 2);
      expect(chunks.map((c) => c.length).toList(), [2, 2, 1]);
    });

    test('non-positive size throws', () {
      expect(
        () => FirestoreBatchUtils.chunk([1], size: 0),
        throwsArgumentError,
      );
    });
  });
}
```

**Edge cases to preserve:**
- Empty result set: `applyInChunks` with an empty `refs` list commits nothing and returns 0 — matches the old behavior of committing an empty batch (which was a harmless no-op).
- `_clearHistory`'s success snackbar still reports `snapshot.docs.length` — unchanged; it is correct because a thrown chunk aborts before the snackbar.
- Partial-failure semantics change slightly: with 1,200 docs, a failure on chunk 3 leaves 900 already deleted. That is strictly better than the old behavior (total failure, nothing deleted, no path to success) and deletes are idempotent — the user re-runs Clear History for the remainder. Do NOT wrap in a transaction (transactions have the same 500-op limit).
- Do not touch `_deleteAccount`'s batch in this commit (Step 2 rewrites that whole method) or `edit_profile_screen.dart` (Step 3 removes its batch entirely).

**Acceptance criteria:**
- A user with more than 500 readings taps Settings (tab index 4) → Clear History → Clear, and ALL readings are deleted; the success snackbar shows the full count.
- No behavior change for users with ≤450 readings.

**Verify:**
```
flutter analyze
flutter test test/unit/firestore_batch_utils_test.dart
```
(Do NOT gate on the full `flutter test` suite — audit finding arch-2 documents 53 pre-existing failures unrelated to this cluster.)
Manual: seed >500 readings for a test account (or record for ~45 min at the 5 s save cadence), Settings tab → Clear History → Clear → History tab (index 3) is empty and Firestore console shows zero docs for that uid.

---

### Step 2 — Re-authenticate BEFORE anonymizing anything in account deletion

**Finding IDs:** settings-1, sec-3, flow6-01 (Critical) + the Delete Account leg of arch-4/flow6-05
**Goal:** Make the only step that can fail with `requires-recent-login` (re-authentication) run FIRST, so a stale session can never destroy the user's data while leaving the account alive; chunk the anonymize batch while rewriting the method.

**Files:**
- `lib/screens/settings_screen_enhanced.dart`

**Commit title:** `fix(settings): re-authenticate before anonymizing data in account deletion`

**Exact changes:**

2a. Add the AppLogger import (imports as left by Step 1b).

BEFORE:
```dart
import 'donation_screen.dart';
import '../utils/theme_helper.dart';
import '../utils/firestore_batch_utils.dart';
```

AFTER:
```dart
import 'donation_screen.dart';
import '../utils/theme_helper.dart';
import '../utils/firestore_batch_utils.dart';
import '../utils/app_logger.dart';
```

2b. Replace `_showDeleteAccountConfirmation` (currently lines 827–861) IN FULL. It now collects the password needed for re-authentication, mirroring the change-password dialog's field styling.

BEFORE:
```dart
  // Delete account confirmation
  void _showDeleteAccountConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeHelper.getCardColor(context),
        title: const Text(
          'Delete Account?',
          style: TextStyle(color: Colors.red),
        ),
        content: Text(
          'This will delete your account, but your noise recordings will be preserved as anonymous community data to help reduce noise pollution. This action cannot be undone.',
          style: TextStyle(color: ThemeHelper.getSecondaryTextColor(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: ThemeHelper.getSecondaryTextColor(context),
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteAccount();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
```

AFTER:
```dart
  // Delete account confirmation. Collects the password up front because
  // deletion re-authenticates BEFORE touching any data
  // (settings-1/sec-3/flow6-01).
  void _showDeleteAccountConfirmation() {
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeHelper.getCardColor(context),
        title: const Text(
          'Delete Account?',
          style: TextStyle(color: Colors.red),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'This will delete your account, but your noise recordings will be preserved as anonymous community data to help reduce noise pollution. This action cannot be undone.\n\nEnter your password to confirm.',
              style: TextStyle(
                color: ThemeHelper.getSecondaryTextColor(context),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              style: TextStyle(color: ThemeHelper.getTextColor(context)),
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: TextStyle(
                  color: ThemeHelper.getSecondaryTextColor(context),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: ThemeHelper.getSecondaryTextColor(context),
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final password = passwordController.text.trim();
              if (password.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter your password to confirm'),
                  ),
                );
                return;
              }
              Navigator.pop(context);
              await _deleteAccount(password);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
```

2c. Replace `_deleteAccount` (currently lines 863–959) IN FULL.

BEFORE:
```dart
  // Delete account implementation
  Future<void> _deleteAccount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      // Show loading indicator
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(
            color: ThemeHelper.getPrimaryColor(context),
          ),
        ),
      );

      // Step 1: Anonymize user's noise readings (DON'T DELETE - preserve community data!)
      final uid = user.uid;
      final firestore = FirebaseFirestore.instance;

      final snapshot = await firestore
          .collection('noise_readings')
          .where('userId', isEqualTo: uid)
          .get();

      // Update all readings to anonymize user info (preserve the valuable data)
      final batch = firestore.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {
          'userEmail': 'Deleted User',
          'userId': 'deleted_user_${uid.substring(0, 8)}',
          // Keep partial ID for data integrity
        });
      }
      await batch.commit();

      // Step 2: Delete the Firebase Auth user (but data stays!)
      await user.delete();

      // Close loading dialog
      if (!mounted) return;
      Navigator.pop(context); // Close loading

      // Navigate to login screen and clear all previous routes
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseAuthException catch (e) {
      // Close loading dialog if open
      if (mounted) {
        Navigator.pop(context);
      }

      String errorMessage = 'Failed to delete account';

      if (e.code == 'requires-recent-login') {
        errorMessage =
            'Please log out and log in again before deleting your account';
      } else {
        errorMessage = 'Error: ${e.message ?? e.code}';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      // Close loading dialog if open
      if (mounted) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
```

AFTER:
```dart
  // Delete account implementation.
  // Order is CRITICAL (settings-1/sec-3/flow6-01):
  //   1. Re-authenticate — the only step that can fail with
  //      requires-recent-login, so it must fail BEFORE any data is
  //      touched (mirrors the change-password flow above).
  //   2. Anonymize readings in chunked batches (arch-4/flow6-05).
  //   3. Delete the Firebase Auth user.
  Future<void> _deleteAccount(String password) async {
    var loadingShown = false;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        throw Exception('No user logged in');
      }

      // Show loading indicator
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(
            color: ThemeHelper.getPrimaryColor(context),
          ),
        ),
      );
      loadingShown = true;

      // Step 1: Re-authenticate FIRST. Destructive writes only run once
      // Firebase has accepted a fresh credential, so a stale session can
      // never orphan the user's data.
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      // Step 2: Anonymize user's noise readings (DON'T DELETE - preserve
      // community data!) in chunked batches.
      final uid = user.uid;
      final firestore = FirebaseFirestore.instance;

      final snapshot = await firestore
          .collection('noise_readings')
          .where('userId', isEqualTo: uid)
          .get();

      await FirestoreBatchUtils.applyInChunks(
        firestore,
        snapshot.docs.map((doc) => doc.reference).toList(),
        (batch, ref) => batch.update(ref, {
          'userEmail': 'Deleted User',
          'userId': 'deleted_user_${uid.substring(0, 8)}',
          // Keep partial ID for data integrity
        }),
      );

      // Step 3: Delete the Firebase Auth user (but data stays!)
      await user.delete();

      // Close loading dialog
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      loadingShown = false;

      // Navigate to login screen and clear all previous routes
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseAuthException catch (e) {
      AppLogger.error('[Settings] Account deletion failed', e);

      // Close loading dialog if open
      if (loadingShown && mounted) {
        Navigator.pop(context);
      }

      String errorMessage = 'Failed to delete account';

      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        errorMessage =
            'Password is incorrect. Your account and data were NOT changed.';
      } else if (e.code == 'requires-recent-login') {
        errorMessage =
            'Please log out and log in again before deleting your account';
      } else {
        errorMessage = 'Error: ${e.message ?? e.code}';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      AppLogger.error('[Settings] Account deletion failed', e);

      // Close loading dialog if open
      if (loadingShown && mounted) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
```

**Edge cases to preserve:**
- Wrong password now aborts BEFORE any write — zero data touched. Handle BOTH `wrong-password` and `invalid-credential` (newer firebase_auth SDKs report the latter for bad passwords).
- The `loadingShown` flag fixes a latent bug in the old code: if the method threw before `showDialog` (e.g. `user == null`), the catch's unconditional `Navigator.pop(context)` popped the Settings route itself. Keep the flag exactly as written.
- Keep the anonymized values byte-identical (`'Deleted User'`, `'deleted_user_${uid.substring(0, 8)}'`) — community-feed and map readers already display these.
- The anonymize update touches only `userEmail`/`userId`; it must NOT rewrite `timestamp`/`createdAt` (dual-timestamp convention applies to reading creation, not to this partial update).
- Success-path navigation and the post-navigation snackbar behavior (delivered via the root ScaffoldMessenger) stay as-is; do not "fix" the LoginScreen-vs-SplashScreen destination inconsistency here (flow1-9, out of scope).
- Residual (accepted) risk: if `user.delete()` fails AFTER a successful reauth + anonymize (e.g. network drop in the final second), data is anonymized while the account survives. Re-authentication removes the systematic `requires-recent-login` cause, which is the entire Critical finding; the remaining window is a transient-network corner. Do not attempt a client-side rollback (rewriting emails back would be its own PII bug).

**Acceptance criteria:**
- Delete Account with the WRONG password → red "Password is incorrect..." snackbar, account still works, History (tab 3) and Analytics (tab 1) unchanged, Firestore docs unchanged.
- Delete Account with the correct password on a session that is DAYS old → succeeds in one pass (no requires-recent-login), readings anonymized, auth user gone, app lands on LoginScreen.
- Works for a user with >500 readings (chunked anonymize).

**Verify:**
```
flutter analyze
flutter test test/unit/firestore_batch_utils_test.dart
```
Manual: (1) create a throwaway account, record a few readings, Settings tab → Delete Account → enter a wrong password → confirm nothing changed in Firestore. (2) Repeat with the correct password → confirm all that account's `noise_readings` docs now show `userEmail: 'Deleted User'` / `userId: 'deleted_user_...'` and the Auth user is gone from the Firebase console.

---

### Step 3 — Propagate email to Firestore only after the Auth email is actually verified

**Finding IDs:** settings-9, flow6-06 + the edit-profile leg of arch-4/flow6-05 (and incidentally flow6-07, the empty name-only batch, whose code block is removed)
**Goal:** Stop writing unverified emails into `users/{uid}` and `noise_readings`; instead reconcile Firestore FROM the Auth email at app-shell startup, so Firestore can never diverge from the login identity.

**Files:**
- `lib/screens/edit_profile_screen.dart`
- `lib/services/profile_sync_service.dart` (new)
- `lib/widgets/main_app_shell.dart`

**Commit title:** `fix(profile): propagate email to Firestore only after Auth email is verified`

**Exact changes:**

3a. `lib/screens/edit_profile_screen.dart` — replace the email branch AND the readings-batch block (lines 98–141) with a verify-only branch.

BEFORE:
```dart
      // Update email (this is more sensitive and requires re-authentication)
      if (emailChanged) {
        await user.verifyBeforeUpdateEmail(newEmail);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Verification email sent! Please check your new email address and verify it.',
              ),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 5),
            ),
          );
        }

        // Update Firestore users collection with new email
        await _firestore.collection('users').doc(user.uid).set({
          'email': newEmail,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedAtClient': DateTime.now(), // Fallback timestamp
        }, SetOptions(merge: true));
      }

      // Reload user to get updated info
      await user.reload();

      // Update Firestore noise_readings with new user info
      if (emailChanged || nameChanged) {
        final snapshot = await _firestore
            .collection('noise_readings')
            .where('userId', isEqualTo: user.uid)
            .get();

        if (snapshot.docs.isNotEmpty) {
          final batch = _firestore.batch();
          for (var doc in snapshot.docs) {
            batch.update(doc.reference, {
              if (emailChanged) 'userEmail': newEmail,
            });
          }
          await batch.commit();
        }
      }
```

AFTER:
```dart
      // Update email (this is more sensitive and requires re-authentication)
      if (emailChanged) {
        // settings-9/flow6-06: verifyBeforeUpdateEmail only SENDS a
        // verification link — the Auth email does not change until the
        // user clicks it. Do NOT write the new email to Firestore here.
        // ProfileSyncService.reconcileUserEmail() (run at app-shell
        // startup) propagates it to users/{uid} and noise_readings once
        // the Auth email has actually changed.
        await user.verifyBeforeUpdateEmail(newEmail);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Verification email sent! Your profile will update automatically after you verify the new address and sign in again.',
              ),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }

      // Reload user to get updated info
      await user.reload();
```

(Note: `_firestore` remains used by the name-change branch at lines 90–95, and `FieldValue` by the same block — no import removals. The name-only save no longer fetches every reading and commits empty updates, which also resolves audit note flow6-07.)

3b. NEW FILE `lib/services/profile_sync_service.dart` — full contents:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_logger.dart';
import '../utils/firestore_batch_utils.dart';

/// Reconciles the VERIFIED FirebaseAuth email into Firestore
/// (users/{uid}.email and noise_readings.userEmail).
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

  /// '<uid>:<email>' of the last successful (or already-consistent)
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

      final updated = await FirestoreBatchUtils.applyInChunks(
        _firestore,
        snapshot.docs.map((doc) => doc.reference).toList(),
        (batch, ref) => batch.update(ref, {'userEmail': authEmail}),
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
```

3c. `lib/widgets/main_app_shell.dart` — imports (lines 1–8) and `initState` (lines 22–26).

BEFORE:
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screens/map_view_screen.dart';
```

AFTER:
```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screens/map_view_screen.dart';
```

BEFORE:
```dart
import '../screens/settings_screen_enhanced.dart';
import 'shared_bottom_navbar.dart';
```

AFTER:
```dart
import '../screens/settings_screen_enhanced.dart';
import '../services/profile_sync_service.dart';
import 'shared_bottom_navbar.dart';
```

BEFORE:
```dart
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }
```

AFTER:
```dart
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    // settings-9/flow6-06: if the user completed an email-change
    // verification since last launch, copy the now-verified Auth email
    // onto their Firestore documents. Fire-and-forget; never blocks UI.
    unawaited(ProfileSyncService().reconcileUserEmail());
  }
```

**Edge cases to preserve:**
- Name-only saves: `updateDisplayName` + `users/{uid}` merge-set (lines 86–95) are untouched and still complete immediately.
- The success snackbar at lines 145–154 ("Profile updated! Please verify your new email.") and the delayed pop stay as-is.
- `requires-recent-login` from `verifyBeforeUpdateEmail` is still handled by the existing `FirebaseAuthException` switch (lines 167–192) — untouched.
- Users who never click the verification link now diverge NOWHERE: Auth, `users/{uid}`, and all readings keep the old email consistently. That is the fix.
- Users doc write keeps the exact existing field shape (`email`, `updatedAt` serverTimestamp, `updatedAtClient` client DateTime) — mirrors edit_profile/registration writers so any future reader handles both timestamps.
- `ProfileSyncService` must never throw out of `reconcileUserEmail` (it is unawaited in initState).
- MainAppShell is const-constructed with `IndexedStack` children — do not reorder tabs (Map=0, Analytics=1, Dashboard=2, History=3, Settings=4).

**Acceptance criteria:**
- Change email but DON'T click the link → `users/{uid}.email` and every reading's `userEmail` still show the OLD email; login still uses the old email; Community Feed shows the old masked email. No divergence.
- Change email, click the link, sign in with the NEW email → within seconds of MainAppShell appearing, `users/{uid}.email` and all that user's readings' `userEmail` equal the new email (verify in Firestore console; works for >500 readings via chunking).
- Log shows exactly one `[ProfileSync] Propagated...` line; relaunching the app does not rewrite anything (no-op path).

**Verify:**
```
flutter analyze
flutter test test/unit/firestore_batch_utils_test.dart
```
Manual: run the two scenarios in Acceptance criteria against a test account with a reachable inbox. Also confirm a name-only save no longer produces any `noise_readings` writes (watch Firestore usage/logs).

---

### Step 4 — Flush the offline queue on logout and abort in-flight sync on auth change

**Finding IDs:** flow6-02 (E2E audit `audit/03_E2E_FLOW_AUDIT.md:1868`)
**Prerequisite:** `audit/playbook/02_offline_sync_overhaul.md` fully applied. The BEFORE blocks below are the file state AFTER cluster 02 (its Steps 3 and 7); they will NOT match the pre-cluster-02 file. If they don't match, STOP and apply cluster 02 first.
**Goal:** Best-effort upload of this user's pending recordings before `signOut`, and a hard guard so a sync that is mid-flight when the auth state changes stops immediately instead of writing with a stale identity.

**Files:**
- `lib/screens/dashboard_screen.dart`
- `lib/services/sync_service.dart`

**Commit title:** `fix(sync): flush offline queue on logout and abort in-flight sync on auth change`

**Exact changes:**

4a. `lib/screens/dashboard_screen.dart` — add the SyncService import (imports, lines 20–24).

BEFORE:
```dart
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../services/sound_classification_service.dart';
```

AFTER:
```dart
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../services/sound_classification_service.dart';
import '../services/sync_service.dart';
```

4b. Same file — the logout IconButton (lines 681–703; not modified by cluster 02).

BEFORE:
```dart
          // Logout button - same color as Dashboard title
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // Capture navigator before async operation
              final navigator = Navigator.of(context);

              // Sign out from Firebase
              await FirebaseAuth.instance.signOut();

              // Clear navigation stack and go to splash screen
              // This ensures user cannot go back to authenticated screens
              if (mounted) {
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const SplashScreen(),
                  ),
                  (route) => false, // Remove all previous routes
                );
              }
            },
            tooltip: 'Logout',
          ),
```

AFTER:
```dart
          // Logout button - same color as Dashboard title
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // Capture navigator before async operation
              final navigator = Navigator.of(context);

              // flow6-02: best-effort flush of the offline queue while
              // this user is still authenticated. Bounded so logout can
              // never hang; anything not uploaded stays queued in Hive
              // tagged with this user's uid (cluster 02) and syncs on
              // their next sign-in.
              final syncService = SyncService();
              if (syncService.isOnline() &&
                  syncService.getPendingCount() > 0) {
                try {
                  await syncService
                      .triggerManualSync()
                      .timeout(const Duration(seconds: 15));
                } on TimeoutException {
                  AppLogger.warning(
                    '[Dashboard] Pre-logout sync timed out; remaining recordings stay queued for this user',
                  );
                } catch (e) {
                  AppLogger.error('[Dashboard] Pre-logout sync failed', e);
                }
              }

              // Sign out from Firebase
              await FirebaseAuth.instance.signOut();

              // Clear navigation stack and go to splash screen
              // This ensures user cannot go back to authenticated screens
              if (mounted) {
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const SplashScreen(),
                  ),
                  (route) => false, // Remove all previous routes
                );
              }
            },
            tooltip: 'Logout',
          ),
```

(`TimeoutException` and `AppLogger` need no new imports: `dart:async` is imported at line 2 and `../utils/app_logger.dart` at line 12.)

4c. `lib/services/sync_service.dart` — sign-out branch in `_onAuthStateChanged`. BEFORE is exactly the method as created by cluster 02 Step 7c.

BEFORE:
```dart
  /// Sync pending recordings when a user signs in (offline-3). The stream
  /// also fires once on listen with the restored session, covering startup.
  void _onAuthStateChanged(User? user) {
    if (user == null) return;
    if (_isOnline && _storage.getPendingCount() > 0) {
      AppLogger.info(
        '[SyncService] User ${user.uid} signed in with pending recordings. Starting sync...',
      );
      unawaited(syncOfflineRecordings());
    }
  }
```

AFTER:
```dart
  /// Sync pending recordings when a user signs in (offline-3). The stream
  /// also fires once on listen with the restored session, covering startup.
  ///
  /// On sign-out (flow6-02) nothing is uploaded and nothing is destroyed:
  /// pending entries stay in Hive tagged with their owner's userId
  /// (cluster 02), and the mid-sync guard in syncOfflineRecordings stops
  /// any in-flight sync from writing without an authenticated session.
  void _onAuthStateChanged(User? user) {
    if (user == null) {
      final pending = _storage.getPendingCount();
      if (pending > 0) {
        AppLogger.info(
          '[SyncService] User signed out with $pending pending recordings. '
          'They remain queued for their owner and sync on next sign-in.',
        );
      }
      return;
    }
    if (_isOnline && _storage.getPendingCount() > 0) {
      AppLogger.info(
        '[SyncService] User ${user.uid} signed in with pending recordings. Starting sync...',
      );
      unawaited(syncOfflineRecordings());
    }
  }
```

4d. Same file — mid-sync abort guard at the top of the sync loop. BEFORE is the loop head exactly as left by cluster 02 Step 3a.

BEFORE:
```dart
      for (final recording in queuedRecordings) {
        // Check if max attempts exceeded
        if (recording.syncAttempts >= maxSyncAttempts) {
          AppLogger.warning(
            '[SyncService] Skipping ${recording.id}: Max sync attempts ($maxSyncAttempts) exceeded',
          );
          continue;
        }
```

AFTER:
```dart
      for (final recording in queuedRecordings) {
        // flow6-02: abort mid-sync if the session ended (logout) or the
        // user changed since this sync started — never write with a
        // stale identity. Remaining recordings stay queued.
        if (_auth.currentUser?.uid != user.uid) {
          AppLogger.warning(
            '[SyncService] Auth state changed mid-sync. Aborting; remaining recordings stay queued.',
          );
          break;
        }

        // Check if max attempts exceeded
        if (recording.syncAttempts >= maxSyncAttempts) {
          AppLogger.warning(
            '[SyncService] Skipping ${recording.id}: Max sync attempts ($maxSyncAttempts) exceeded',
          );
          continue;
        }
```

(`user` here is the local `final user = _auth.currentUser;` captured at the top of `syncOfflineRecordings` — already null-checked before the loop; no signature changes.)

**Edge cases to preserve:**
- `triggerManualSync()` (post-cluster-02) resets dead-lettered attempts before syncing — desirable at logout too; do not special-case it.
- `.timeout()` does NOT cancel the underlying future. If the 15 s bound fires, the sync keeps running in the background while `signOut()` proceeds — and that is exactly what the 4d guard exists for: the loop observes `_auth.currentUser == null` and breaks before the next upload. The one upload possibly in flight at that instant belongs to the correct (pre-logout) user with data captured while authenticated; if Firestore rejects it post-signout, the entry stays queued and re-syncs idempotently on next sign-in (cluster 02 deterministic doc IDs). No data loss either way.
- Offline logout: the flush block is skipped entirely (`isOnline()` false) — logout must never block waiting for a network.
- Do NOT clear or delete the Hive queue on logout. Entries are user-tagged; wiping them would destroy another-user's or this-user's unsynced data. Persistence across sessions is the design (cluster 02 explicitly kept foreign entries queued).
- Do NOT call `SyncService().dispose()` on logout — it is a process-lifetime singleton; disposing closes the Hive boxes and kills connectivity monitoring for the next user.
- The `mounted` check before navigation and the SplashScreen destination stay untouched (flow1-9/settings-13 are out of scope).

**Acceptance criteria:**
- Record readings in airplane mode, re-enable wifi, immediately tap Logout → logout pauses briefly, the readings appear in Firestore under the logging-out user's uid, then the app lands on SplashScreen.
- With wifi disabled, Logout is instant and the queue is intact (visible after next sign-in via the pending badge).
- Sign out while a large sync is mid-flight (many queued readings, tap Logout then immediately kill wifi so the flush times out) → log shows "Auth state changed mid-sync. Aborting"; no Firestore doc is ever written after sign-out with a stale uid; remaining entries sync on the owner's next sign-in.
- Log out with pending entries → log shows the "remain queued for their owner" info line.

**Verify:**
```
flutter analyze
flutter test test/unit/offline_recording_test.dart
flutter test test/unit/firestore_batch_utils_test.dart
```
Manual: run the three scenarios above watching `AppLogger` output and the Firestore console. Confirm user B signing in after user A's aborted flush does NOT upload A's entries under B (cluster 02 foreign-skip + this guard together).

---

## Risks & rollback

- **Step interdependence:** Step 1 must land first — Steps 2 and 3 call `FirestoreBatchUtils.applyInChunks`. Step 4 additionally requires cluster 02 (playbook 02) to be fully applied; its BEFORE blocks are written against that state and will not match otherwise.
- **Step 2 residual window:** after reauth+anonymize, a failed `user.delete()` (transient network) leaves data anonymized with the account alive. Accepted: the systematic cause (requires-recent-login on stale sessions — the Critical finding) is eliminated; no client-side rollback is attempted. Note also that the Dashboard's 5-second auto-save can be recording during deletion (dash-6, separate cluster): a reading saved between the anonymize pass and `user.delete()` would keep the live uid. Rollback: revert the commit; the old single-batch flow returns (with its Critical bug).
- **Step 3 propagation latency:** between clicking the verification link and the next sign-in, `users/{uid}`/readings still show the old email. That is consistent-but-stale (matches what login accepts at every instant), strictly better than the old consistent-with-nothing state. If product later wants instant propagation, add a `user.reload()`-based check on app resume — do not go back to writing form input. Rollback: revert the commit; divergence bug returns but nothing structural breaks (`ProfileSyncService` has no other callers).
- **Chunked commits are not atomic:** a mid-sequence failure leaves a partially-cleared / partially-anonymized / partially-propagated set. All three operations are idempotent re-runs (delete, fixed-value update), and each screen/service path can simply be triggered again. Firestore transactions are NOT an alternative (same 500-op ceiling).
- **Step 4 logout latency:** worst case logout takes ~15 s when a flush is running. Bounded by the explicit `.timeout`; offline logout is unaffected. Rollback: revert the commit; logout returns to instant-but-leaky.
- **No new Firestore index** anywhere in this spec (all queries equality-only on `userId`). If any future extension of these flows adds a period filter, it must use `isGreaterThan` + `orderBy('timestamp', descending: true)` on the existing `noise_readings (userId ASC, timestamp DESC)` index — never `isGreaterThanOrEqualTo`.
- **Test suite:** gate every commit on `flutter analyze` plus the named unit test files only. The full `flutter test` run has 53 pre-existing failures (audit arch-2); do not let them block, and do not fix them here.

## Out of scope

Explicitly NOT addressed here (separate findings — do not drive-by fix):

- settings-11 — `users/{uid}` profile doc (PII) is never deleted on account deletion.
- flow6-17 — no Sign Out entry in Settings (logout only via Dashboard app-bar icon).
- flow1-9 / flow6-09 / settings-13 — inconsistent logout/delete landing screens, onboarding replay on every logout, SharedAppState/notification cleanup on logout.
- sec-2 / social-8 / fb-4 — email+coordinates PII exposure in shared docs, weak client-side masking, global CSV export.
- flow6-08 — `users` collection is write-only app-wide (Step 3 keeps writing it for consistency; making it read is a feature change).
- dash-6 — recording continuing during Settings flows (interacts with Step 2's residual risk; fix belongs to the dashboard cluster).
- arch-16-style logging sweeps — AppLogger lines were added only inside code this spec rewrites.
- Everything in `audit/playbook/02_offline_sync_overhaul.md` — prerequisite, not part of this cluster.
