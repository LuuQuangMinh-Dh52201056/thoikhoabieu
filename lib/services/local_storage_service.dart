import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/schedule_item.dart';

class LocalStorageService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  LocalStorageService({FirebaseFirestore? db, FirebaseAuth? auth})
    : _db = db ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _schedules =>
      _db.collection('schedules');

  Future<List<ScheduleItem>> getSchedules() async {
    final snapshot = await _schedules.get();

    final items = snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = data['id']?.toString().isNotEmpty == true
          ? data['id']
          : doc.id;
      return ScheduleItem.fromMap(data);
    }).toList();

    items.sort(_compareSchedule);
    return items;
  }

  Future<void> addSchedule(ScheduleItem item) async {
    final user = _requireUser();
    final id = item.id.trim().isEmpty ? _schedules.doc().id : item.id;
    final itemWithOwner = item.copyWith(
      id: id,
      createdBy: user.uid,
      createdByEmail: user.email ?? '',
    );

    await _schedules.doc(id).set({
      ...itemWithOwner.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': user.uid,
    });
  }

  Future<void> updateSchedule(ScheduleItem updatedItem) async {
    final user = _requireUser();
    final document = _schedules.doc(updatedItem.id);
    final existing = await document.get();

    var itemToSave = updatedItem;
    if (existing.exists && existing.data() != null) {
      final data = existing.data()!;
      data['id'] = existing.id;
      final currentItem = ScheduleItem.fromMap(data);
      itemToSave = updatedItem.copyWith(
        createdBy: currentItem.createdBy,
        createdByEmail: currentItem.createdByEmail,
      );
    }

    await document.set({
      ...itemToSave.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': user.uid,
    }, SetOptions(merge: true));
  }

  Future<void> deleteSchedule(String id) async {
    await _schedules.doc(id).delete();
  }

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Bạn cần đăng nhập trước khi lưu lịch.');
    }
    return user;
  }

  int _compareSchedule(ScheduleItem a, ScheduleItem b) {
    final aDateTime = DateTime(
      a.date.year,
      a.date.month,
      a.date.day,
      a.startHour,
    );
    final bDateTime = DateTime(
      b.date.year,
      b.date.month,
      b.date.day,
      b.startHour,
    );
    return aDateTime.compareTo(bDateTime);
  }
}
