import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import '../models/schedule_item.dart';

class LocalStorageService {
  static const String _localSchedulesKey = 'local_schedules';

  final FirebaseFirestore? _providedDb;
  final FirebaseAuth? _providedAuth;

  LocalStorageService({FirebaseFirestore? db, FirebaseAuth? auth})
    : _providedDb = db,
      _providedAuth = auth;

  bool get _useFirebase => FirebaseEnv.isConfigured;

  FirebaseFirestore get _db => _providedDb ?? FirebaseFirestore.instance;

  FirebaseAuth get _auth => _providedAuth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _schedules =>
      _db.collection('schedules');

  Future<List<ScheduleItem>> getSchedules() async {
    if (!_useFirebase) {
      final items = await _getLocalSchedules();
      items.sort(_compareSchedule);
      return items;
    }

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
    if (!_useFirebase) {
      final items = await _getLocalSchedules();
      final id = item.id.trim().isEmpty
          ? DateTime.now().millisecondsSinceEpoch.toString()
          : item.id;
      items.add(
        item.copyWith(
          id: id,
          createdBy: 'local-demo-user',
          createdByEmail: 'local@thoikhoabieu.app',
        ),
      );
      await _saveLocalSchedules(items);
      return;
    }

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
    if (!_useFirebase) {
      final items = await _getLocalSchedules();
      final index = items.indexWhere((item) => item.id == updatedItem.id);
      if (index == -1) {
        items.add(
          updatedItem.copyWith(
            createdBy: 'local-demo-user',
            createdByEmail: 'local@thoikhoabieu.app',
          ),
        );
      } else {
        final current = items[index];
        items[index] = updatedItem.copyWith(
          createdBy: current.createdBy,
          createdByEmail: current.createdByEmail,
        );
      }
      await _saveLocalSchedules(items);
      return;
    }

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
    if (!_useFirebase) {
      final items = await _getLocalSchedules();
      items.removeWhere((item) => item.id == id);
      await _saveLocalSchedules(items);
      return;
    }

    await _schedules.doc(id).delete();
  }

  Future<List<ScheduleItem>> _getLocalSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localSchedulesKey);
    if (raw == null || raw.trim().isEmpty) return [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];

    return decoded
        .whereType<Map>()
        .map((item) => ScheduleItem.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> _saveLocalSchedules(List<ScheduleItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(items.map((item) => item.toMap()).toList());
    await prefs.setString(_localSchedulesKey, encoded);
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
