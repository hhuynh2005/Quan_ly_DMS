import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../database/app_database.dart';
import '../database/tables.dart';
import 'document_model.dart';
import 'google_auth_service.dart';
import 'subject_model.dart';

class CloudSyncResult {
  final int uploaded;
  final int downloaded;
  final int deleted;

  const CloudSyncResult({
    required this.uploaded,
    required this.downloaded,
    required this.deleted,
  });
}

class CloudSyncService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final AppDatabase _database;
  Future<CloudSyncResult>? _activeSync;

  CloudSyncService({
    required AppDatabase database,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : this._(
         database,
         auth ?? FirebaseAuth.instance,
         firestore ?? FirebaseFirestore.instance,
       );

  CloudSyncService._(this._database, this._auth, this._firestore);

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authChanges => _auth.authStateChanges();

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> createAccount(String email, String password) async {
    await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() => _auth.signOut();

  Future<CloudSyncResult> sync() {
    final active = _activeSync;
    if (active != null) return active;
    final operation = _sync().timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        return const CloudSyncResult(uploaded: 0, downloaded: 0, deleted: 0);
      },
    );
    _activeSync = operation;
    return operation.whenComplete(() => _activeSync = null);
  }

  Future<CloudSyncResult> _sync() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Đăng nhập Firebase trước khi đồng bộ.');
    }

    final userRef = _firestore.collection('users').doc(user.uid);
    final uploadedLogs = await _mergeDeleteLogs(userRef);
    var uploaded = uploadedLogs;
    var downloaded = 0;
    var deleted = 0;

    final subjectResult = await _mergeRecords<Subject>(
      collection: userRef.collection('subjects'),
      localRecords: await _database.getAllSubjects(),
      idOf: (subject) => subject.id,
      modifiedAtOf: (subject) => subject.dateModified,
      dataOf: (subject) => subject.toMap(),
      fromData: Subject.fromMap,
      applyRemote: _database.applySyncedSubject,
    );
    uploaded += subjectResult.uploaded;
    downloaded += subjectResult.downloaded;
    deleted += subjectResult.deleted;

    final resolvedEmail = (user.email != null && user.email!.isNotEmpty)
        ? user.email!
        : (GoogleAuthService().currentUserEmail.isNotEmpty
            ? GoogleAuthService().currentUserEmail
            : 'user_${user.uid.substring(0, 6)}@e.tlu.edu.vn');
    final resolvedName = (user.displayName != null && user.displayName!.isNotEmpty)
        ? user.displayName!
        : (GoogleAuthService().currentUserDisplayName.isNotEmpty
            ? GoogleAuthService().currentUserDisplayName
            : resolvedEmail.split('@').first);

    final documentResult = await _mergeRecords<Document>(
      collection: userRef.collection('documents'),
      localRecords: await _database.getAllDocuments(),
      idOf: (document) => document.id,
      modifiedAtOf: (document) => document.dateModified,
      dataOf: (document) {
        final data = document.toMap();
        data['uploaderUid'] = user.uid;
        data['uploaderEmail'] = resolvedEmail;
        data['uploaderName'] = resolvedName;
        data['owner_id'] = user.uid;
        data['owner_email'] = resolvedEmail;
        data['syncedAt'] = DateTime.now().toUtc().toIso8601String();
        return data;
      },
      fromData: Document.fromMap,
      applyRemote: _database.applySyncedDocument,
    );
    uploaded += documentResult.uploaded;
    downloaded += documentResult.downloaded;
    deleted += documentResult.deleted;

    uploaded += await _mergeDeleteLogs(userRef);
    await userRef.set({
      'uid': user.uid,
      'email': resolvedEmail,
      'displayName': resolvedName,
      'photoURL': user.photoURL ?? '',
      'lastSyncedAt': DateTime.now().toUtc().toIso8601String(),
      'schemaVersion': 1,
    }, SetOptions(merge: true));

    return CloudSyncResult(
      uploaded: uploaded,
      downloaded: downloaded,
      deleted: deleted,
    );
  }

  Future<int> _mergeDeleteLogs(
    DocumentReference<Map<String, dynamic>> userRef,
  ) async {
    final localLogs = await _database.getDeleteLogs();
    final remoteLogs = await userRef.collection('delete_logs').get();
    final remoteIds = remoteLogs.docs.map((doc) => doc.id).toSet();
    var uploaded = 0;

    for (final log in localLogs) {
      final id = log['id'] as String;
      if (!remoteIds.contains(id)) {
        await userRef.collection('delete_logs').doc(id).set(log);
        uploaded++;
      }
    }

    final localIds = localLogs.map((log) => log['id']).toSet();
    for (final remote in remoteLogs.docs) {
      if (!localIds.contains(remote.id)) {
        await _database.applySyncedDeleteLog({
          ...remote.data(),
          'id': remote.id,
        });
      }
    }
    return uploaded;
  }

  Future<_MergeCounts> _mergeRecords<T>({
    required CollectionReference<Map<String, dynamic>> collection,
    required List<T> localRecords,
    required String Function(T) idOf,
    required DateTime Function(T) modifiedAtOf,
    required Map<String, dynamic> Function(T) dataOf,
    required T Function(Map<String, dynamic>) fromData,
    required Future<void> Function(T) applyRemote,
  }) async {
    final remoteSnapshot = await collection.get();
    final localById = {for (final record in localRecords) idOf(record): record};
    final remoteById = {
      for (final record in remoteSnapshot.docs)
        record.id: {...record.data(), 'id': record.id},
    };
    final deleteLogs = await _database.getDeleteLogs();
    final latestDeletion = <String, DateTime>{};
    for (final log in deleteLogs) {
      final deletedAt = DateTime.tryParse(log['date_deleted'] as String? ?? '');
      if (deletedAt == null) continue;
      final id = log['item_id'] as String?;
      final table = log['table_name'] as String?;
      if (id == null || !_matchesCollection(table, collection.path)) continue;
      final current = latestDeletion[id];
      if (current == null || deletedAt.isAfter(current)) {
        latestDeletion[id] = deletedAt;
      }
    }

    final ids = {...localById.keys, ...remoteById.keys, ...latestDeletion.keys};
    var uploaded = 0;
    var downloaded = 0;
    var deleted = 0;
    for (final id in ids) {
      final local = localById[id];
      final remoteData = remoteById[id];
      final localTime = local == null ? null : modifiedAtOf(local);
      final remoteTime = remoteData == null ? null : _modifiedAt(remoteData);
      final tombstone = latestDeletion[id];
      final newestRecord = _latest(localTime, remoteTime);

      if (tombstone != null &&
          (newestRecord == null || !newestRecord.isAfter(tombstone))) {
        if (local != null) {
          await _database.applySyncedDeleteLog(
            _deleteLogFor(id, collection.path, tombstone),
          );
        }
        if (remoteData != null) {
          await collection.doc(id).delete();
        }
        if (local != null || remoteData != null) deleted++;
        continue;
      }

      if (local != null &&
          (remoteTime == null || localTime!.isAfter(remoteTime))) {
        await collection.doc(id).set(dataOf(local));
        uploaded++;
      } else if (remoteData != null &&
          (localTime == null || remoteTime!.isAfter(localTime))) {
        await applyRemote(fromData(remoteData));
        downloaded++;
      } else if (local != null &&
          remoteData != null &&
          localTime != null &&
          remoteTime != null &&
          localTime.isAtSameMomentAs(remoteTime) &&
          _fingerprint(dataOf(local)).compareTo(_fingerprint(remoteData)) !=
              0) {
        if (_fingerprint(dataOf(local)).compareTo(_fingerprint(remoteData)) >
            0) {
          await collection.doc(id).set(dataOf(local));
          uploaded++;
        } else {
          await applyRemote(fromData(remoteData));
          downloaded++;
        }
      }
    }
    return _MergeCounts(uploaded, downloaded, deleted);
  }

  bool _matchesCollection(String? tableName, String collectionPath) {
    if (collectionPath.endsWith('/documents')) {
      return tableName == AppTables.tableDocuments;
    }
    return tableName == AppTables.tableSubjects;
  }

  Map<String, dynamic> _deleteLogFor(
    String itemId,
    String collectionPath,
    DateTime deletedAt,
  ) {
    return {
      'id': 'sync_${collectionPath.split('/').last}_$itemId',
      'item_id': itemId,
      'table_name': collectionPath.endsWith('/documents')
          ? AppTables.tableDocuments
          : AppTables.tableSubjects,
      'date_deleted': deletedAt.toIso8601String(),
    };
  }

  DateTime? _modifiedAt(Map<String, dynamic> data) {
    final value = data['date_modified'];
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  DateTime? _latest(DateTime? first, DateTime? second) {
    if (first == null) return second;
    if (second == null) return first;
    return first.isAfter(second) ? first : second;
  }

  String _fingerprint(Map<String, dynamic> data) {
    final sorted = Map<String, dynamic>.fromEntries(
      data.entries.toList()
        ..sort((first, second) => first.key.compareTo(second.key)),
    );
    return jsonEncode(sorted);
  }
}

class _MergeCounts {
  final int uploaded;
  final int downloaded;
  final int deleted;

  const _MergeCounts(this.uploaded, this.downloaded, this.deleted);
}
