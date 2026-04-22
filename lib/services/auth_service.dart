import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import '../models/app_user.dart';

class AuthServiceException implements Exception {
  final String message;

  const AuthServiceException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  static String get localAdminUsername {
    final configured = _normalizeUsernameStatic(FirebaseEnv.localAdminUsername);
    if (validateUsernameText(configured) == null) return configured;
    return 'admin01';
  }

  static String get localAdminPassword {
    final configured = FirebaseEnv.localAdminPassword.trim();
    if (configured.length >= 6) return configured;
    return 'admin123456';
  }

  static const _internalEmailDomain = 'accounts.thoikhoabieu.app';

  static const _localUsersKey = 'local_auth_users';
  static const _localCurrentUidKey = 'local_auth_current_uid';
  static const _localResetPassword = '123456';

  static final StreamController<void> _localAuthEvents =
      StreamController<void>.broadcast();

  final FirebaseAuth? _providedAuth;
  final FirebaseFirestore? _providedDb;

  AuthService({FirebaseAuth? auth, FirebaseFirestore? db})
    : _providedAuth = auth,
      _providedDb = db;

  static Stream<void> get localAuthChanges => _localAuthEvents.stream;

  static String? validateUsernameText(String? value) {
    final username = _normalizeUsernameStatic(value ?? '');
    if (username.isEmpty) return 'Nhập tên đăng nhập';
    if (username.length < 3 || username.length > 30) {
      return 'Tên đăng nhập cần từ 3 đến 30 ký tự';
    }
    if (username.contains('@')) return 'Không nhập email ở ô này';
    if (!RegExp(r'^[a-z0-9._-]+$').hasMatch(username)) {
      return 'Chỉ dùng chữ, số, dấu chấm, gạch dưới hoặc gạch ngang';
    }
    if (!RegExp(r'[a-z]').hasMatch(username) ||
        !RegExp(r'[0-9]').hasMatch(username)) {
      return 'Tên đăng nhập phải có cả chữ và số';
    }
    return null;
  }

  static String _normalizeUsernameStatic(String username) {
    return username.trim().toLowerCase();
  }

  FirebaseAuth get _auth => _providedAuth ?? FirebaseAuth.instance;

  FirebaseFirestore get _db => _providedDb ?? FirebaseFirestore.instance;

  Stream<User?> get authStateChanges {
    if (!FirebaseEnv.isConfigured) return const Stream<User?>.empty();
    return _auth.authStateChanges();
  }

  User? get currentUser {
    if (!FirebaseEnv.isConfigured) return null;
    return _auth.currentUser;
  }

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  Future<AppUser?> currentProfile() async {
    if (!FirebaseEnv.isConfigured) {
      final prefs = await SharedPreferences.getInstance();
      final currentUid = prefs.getString(_localCurrentUidKey);
      if (currentUid == null || currentUid.isEmpty) return null;

      final users = await _localUserMaps();
      final current = _findLocalUserByUid(users, currentUid);
      if (current == null) {
        await prefs.remove(_localCurrentUidKey);
        return null;
      }

      final profile = _appUserFromLocalMap(current);
      if (!profile.canSignIn) {
        await prefs.remove(_localCurrentUidKey);
        return null;
      }

      return profile;
    }

    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _users.doc(user.uid).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }

    final profile = AppUser.fromMap(doc.id, doc.data()!);
    if (!profile.canSignIn) return null;
    return profile;
  }

  Future<AppUser> signIn({
    required String username,
    required String password,
  }) async {
    final cleanUsername = _normalizeUsername(username);
    _validateUsername(cleanUsername);

    if (!FirebaseEnv.isConfigured) {
      final users = await _localUserMaps();
      final user = _findLocalUserByUsername(users, cleanUsername);

      if (user == null || user['password']?.toString() != password) {
        throw const AuthServiceException(
          'Tên đăng nhập hoặc mật khẩu không đúng.',
        );
      }

      final profile = _appUserFromLocalMap(user);
      if (!profile.canSignIn) {
        throw const AuthServiceException(
          'Tài khoản chưa được admin cấp quyền hoặc đang bị khóa.',
        );
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localCurrentUidKey, profile.uid);
      _localAuthEvents.add(null);
      return profile;
    }

    try {
      final email = await _firebaseEmailForUsername(cleanUsername);
      await _auth.signInWithEmailAndPassword(email: email, password: password);

      final profile = await currentProfile();
      if (profile == null) {
        await signOut();
        throw const AuthServiceException(
          'Tài khoản chưa được admin cấp quyền hoặc đang bị khóa.',
        );
      }

      return profile;
    } on FirebaseAuthException catch (e) {
      throw AuthServiceException(_authMessage(e));
    }
  }

  Future<void> signOut() async {
    if (!FirebaseEnv.isConfigured) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_localCurrentUidKey);
      _localAuthEvents.add(null);
      return;
    }

    return _auth.signOut();
  }

  Future<List<AppUser>> getUsers() async {
    if (!FirebaseEnv.isConfigured) {
      final profile = await currentProfile();
      if (profile?.isAdmin != true) {
        throw const AuthServiceException(
          'Bạn không có quyền quản lý tài khoản.',
        );
      }

      final users = (await _localUserMaps()).map(_appUserFromLocalMap).toList();
      _sortUsers(users);
      return users;
    }

    final profile = await currentProfile();
    if (profile?.isAdmin != true) {
      throw const AuthServiceException('Bạn không có quyền quản lý tài khoản.');
    }

    final snapshot = await _users.orderBy('displayName').get();
    final users = snapshot.docs
        .map((doc) => AppUser.fromMap(doc.id, doc.data()))
        .toList();
    _sortUsers(users);
    return users;
  }

  Future<AppUser> createUser({
    required String username,
    required String password,
    required String displayName,
    required String role,
  }) async {
    final cleanUsername = _normalizeUsername(username);
    _validateUsername(cleanUsername);

    if (!FirebaseEnv.isConfigured) {
      final admin = await _requireLocalAdmin();
      final cleanName = displayName.trim();

      if (password.length < 6) {
        throw const AuthServiceException('Mật khẩu cần ít nhất 6 ký tự.');
      }
      if (cleanName.isEmpty) {
        throw const AuthServiceException('Nhập tên hiển thị.');
      }

      final users = await _localUserMaps();
      if (_findLocalUserByUsername(users, cleanUsername) != null) {
        throw const AuthServiceException('Tên đăng nhập này đã có tài khoản.');
      }

      final now = DateTime.now().toIso8601String();
      final user = <String, dynamic>{
        'uid': 'local-${DateTime.now().microsecondsSinceEpoch}',
        'username': cleanUsername,
        'email': _internalEmailForUsername(cleanUsername),
        'password': password,
        'displayName': cleanName,
        'role': role == 'admin' ? 'admin' : 'user',
        'active': true,
        'deleted': false,
        'createdAt': now,
        'updatedAt': now,
        'createdBy': admin.uid,
        'updatedBy': admin.uid,
      };

      users.add(user);
      await _saveLocalUserMaps(users);
      return _appUserFromLocalMap(user);
    }

    final admin = await currentProfile();
    if (admin == null || !admin.isAdmin) {
      throw const AuthServiceException('Chỉ admin mới được tạo tài khoản.');
    }

    final secondaryApp = await Firebase.initializeApp(
      name: 'create-user-${DateTime.now().millisecondsSinceEpoch}',
      options: Firebase.app().options,
    );
    final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
    final authEmail = _internalEmailForUsername(cleanUsername);

    User? createdUser;
    try {
      final existingUsername = await _users
          .where('username', isEqualTo: cleanUsername)
          .limit(1)
          .get();
      if (existingUsername.docs.isNotEmpty) {
        throw const AuthServiceException('Tên đăng nhập này đã có tài khoản.');
      }

      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: authEmail,
        password: password,
      );
      createdUser = credential.user;

      if (createdUser == null) {
        throw const AuthServiceException('Không tạo được tài khoản mới.');
      }

      final cleanName = displayName.trim();
      if (cleanName.isNotEmpty) {
        await createdUser.updateDisplayName(cleanName);
      }

      final appUser = AppUser(
        uid: createdUser.uid,
        username: cleanUsername,
        email: createdUser.email ?? authEmail,
        displayName: cleanName,
        role: role == 'admin' ? 'admin' : 'user',
        active: true,
        deleted: false,
      );

      await _users.doc(createdUser.uid).set({
        ...appUser.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdBy': admin.uid,
        'updatedBy': admin.uid,
      });

      return appUser;
    } on FirebaseAuthException catch (e) {
      throw AuthServiceException(_authMessage(e));
    } catch (e) {
      if (createdUser != null) {
        try {
          await createdUser.delete();
        } catch (_) {}
      }
      if (e is AuthServiceException) rethrow;
      throw AuthServiceException('Tạo tài khoản thất bại: $e');
    } finally {
      await secondaryAuth.signOut();
      await secondaryApp.delete();
    }
  }

  Future<void> updateUserRole({
    required String uid,
    required String role,
  }) async {
    if (!FirebaseEnv.isConfigured) {
      await updateUserProfile(
        uid: uid,
        displayName: _appUserFromLocalMap(
          await _requireLocalUser(uid),
        ).displayName,
        role: role,
        active: _appUserFromLocalMap(await _requireLocalUser(uid)).active,
      );
      return;
    }

    final admin = await currentProfile();
    if (admin == null || !admin.isAdmin) {
      throw const AuthServiceException('Chỉ admin mới được đổi quyền.');
    }

    await _users.doc(uid).update({
      'role': role == 'admin' ? 'admin' : 'user',
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': admin.uid,
    });
  }

  Future<void> updateUserProfile({
    required String uid,
    required String displayName,
    required String role,
    required bool active,
  }) async {
    if (!FirebaseEnv.isConfigured) {
      final admin = await _requireLocalAdmin();
      if (uid == admin.uid && (!active || role != 'admin')) {
        throw const AuthServiceException(
          'Bạn không thể tự khóa hoặc tự hạ quyền admin của mình.',
        );
      }

      final users = await _localUserMaps();
      final index = users.indexWhere((user) => user['uid']?.toString() == uid);
      if (index == -1) {
        throw const AuthServiceException('Không tìm thấy tài khoản.');
      }

      users[index] = {
        ...users[index],
        'displayName': displayName.trim(),
        'role': role == 'admin' ? 'admin' : 'user',
        'active': active,
        'deleted': false,
        'updatedAt': DateTime.now().toIso8601String(),
        'updatedBy': admin.uid,
      };
      await _saveLocalUserMaps(users);
      _localAuthEvents.add(null);
      return;
    }

    final admin = await currentProfile();
    if (admin == null || !admin.isAdmin) {
      throw const AuthServiceException('Chỉ admin mới được sửa tài khoản.');
    }
    if (uid == admin.uid && (!active || role != 'admin')) {
      throw const AuthServiceException(
        'Bạn không thể tự khóa hoặc tự hạ quyền admin của mình.',
      );
    }

    await _users.doc(uid).update({
      'displayName': displayName.trim(),
      'role': role == 'admin' ? 'admin' : 'user',
      'active': active,
      'deleted': false,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': admin.uid,
    });
  }

  Future<void> updateUserActive({
    required String uid,
    required bool active,
  }) async {
    if (!FirebaseEnv.isConfigured) {
      final target = await _requireLocalUser(uid);
      await updateUserProfile(
        uid: uid,
        displayName: _appUserFromLocalMap(target).displayName,
        role: _appUserFromLocalMap(target).role,
        active: active,
      );
      return;
    }

    final admin = await currentProfile();
    if (admin == null || !admin.isAdmin) {
      throw const AuthServiceException('Chỉ admin mới được khóa tài khoản.');
    }

    await _users.doc(uid).update({
      'active': active,
      if (active) 'deleted': false,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': admin.uid,
    });
  }

  Future<void> archiveUser(String uid) async {
    if (!FirebaseEnv.isConfigured) {
      final admin = await _requireLocalAdmin();
      if (uid == admin.uid) {
        throw const AuthServiceException(
          'Bạn không thể tự lưu trữ tài khoản admin đang dùng.',
        );
      }

      final users = await _localUserMaps();
      final index = users.indexWhere((user) => user['uid']?.toString() == uid);
      if (index == -1) {
        throw const AuthServiceException('Không tìm thấy tài khoản.');
      }

      users[index] = {
        ...users[index],
        'active': false,
        'deleted': true,
        'deletedAt': DateTime.now().toIso8601String(),
        'deletedBy': admin.uid,
        'updatedAt': DateTime.now().toIso8601String(),
        'updatedBy': admin.uid,
      };
      await _saveLocalUserMaps(users);
      return;
    }

    final admin = await currentProfile();
    if (admin == null || !admin.isAdmin) {
      throw const AuthServiceException('Chỉ admin mới được lưu trữ tài khoản.');
    }
    if (uid == admin.uid) {
      throw const AuthServiceException(
        'Bạn không thể tự lưu trữ tài khoản admin đang dùng.',
      );
    }

    await _users.doc(uid).update({
      'active': false,
      'deleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
      'deletedBy': admin.uid,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': admin.uid,
    });
  }

  Future<void> restoreUser(String uid) async {
    if (!FirebaseEnv.isConfigured) {
      final admin = await _requireLocalAdmin();
      final users = await _localUserMaps();
      final index = users.indexWhere((user) => user['uid']?.toString() == uid);
      if (index == -1) {
        throw const AuthServiceException('Không tìm thấy tài khoản.');
      }

      users[index] = {
        ...users[index],
        'active': true,
        'deleted': false,
        'updatedAt': DateTime.now().toIso8601String(),
        'updatedBy': admin.uid,
      };
      await _saveLocalUserMaps(users);
      return;
    }

    final admin = await currentProfile();
    if (admin == null || !admin.isAdmin) {
      throw const AuthServiceException(
        'Chỉ admin mới được khôi phục tài khoản.',
      );
    }

    await _users.doc(uid).update({
      'active': true,
      'deleted': false,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': admin.uid,
    });
  }

  Future<void> sendPasswordReset(String email) async {
    if (!FirebaseEnv.isConfigured) {
      await _requireLocalAdmin();
      final users = await _localUserMaps();
      final index = users.indexWhere(
        (user) =>
            _normalizeEmail(user['email']?.toString() ?? '') ==
            _normalizeEmail(email),
      );
      if (index == -1) {
        throw const AuthServiceException('Không tìm thấy tài khoản.');
      }

      users[index] = {
        ...users[index],
        'password': _localResetPassword,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await _saveLocalUserMaps(users);
      return;
    }

    final admin = await currentProfile();
    if (admin == null || !admin.isAdmin) {
      throw const AuthServiceException(
        'Chỉ admin mới được gửi đặt lại mật khẩu.',
      );
    }

    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> sendOwnPasswordReset(String email) {
    if (!FirebaseEnv.isConfigured) {
      throw const AuthServiceException(
        'Chế độ local không gửi email. Admin có thể đặt mật khẩu về 123456 trong màn quản lý tài khoản.',
      );
    }

    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<List<Map<String, dynamic>>> _localUserMaps() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localUsersKey);

    List<Map<String, dynamic>> users = [];
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          users = decoded
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }
      } catch (_) {
        users = [];
      }
    }

    var changed = false;
    for (var i = 0; i < users.length; i++) {
      final user = users[i];
      final username = user['username']?.toString().trim();
      if (username == null ||
          username.isEmpty ||
          user['uid'] == 'local-admin') {
        final migratedUsername = user['uid'] == 'local-admin'
            ? localAdminUsername
            : _normalizeUsername(
                user['email']?.toString().split('@').first ?? '',
              );
        users[i] = {
          ...user,
          'username': migratedUsername,
          if ((user['email']?.toString() ?? '').isEmpty ||
              user['uid'] == 'local-admin')
            'email': _internalEmailForUsername(migratedUsername),
        };
        changed = true;
      }
    }

    if (_findLocalUserByUsername(users, localAdminUsername) == null) {
      final now = DateTime.now().toIso8601String();
      users.insert(0, {
        'uid': 'local-admin',
        'username': localAdminUsername,
        'email': _internalEmailForUsername(localAdminUsername),
        'password': localAdminPassword,
        'displayName': 'Admin',
        'role': 'admin',
        'active': true,
        'deleted': false,
        'createdAt': now,
        'updatedAt': now,
      });
      changed = true;
    }

    if (changed) {
      await _saveLocalUserMaps(users);
    }

    return users;
  }

  Future<void> _saveLocalUserMaps(List<Map<String, dynamic>> users) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localUsersKey, jsonEncode(users));
  }

  Future<AppUser> _requireLocalAdmin() async {
    final profile = await currentProfile();
    if (profile?.isAdmin != true) {
      throw const AuthServiceException(
        'Chỉ admin mới được thực hiện thao tác.',
      );
    }
    return profile!;
  }

  Future<Map<String, dynamic>> _requireLocalUser(String uid) async {
    final users = await _localUserMaps();
    final user = _findLocalUserByUid(users, uid);
    if (user == null) {
      throw const AuthServiceException('Không tìm thấy tài khoản.');
    }
    return user;
  }

  Map<String, dynamic>? _findLocalUserByUid(
    List<Map<String, dynamic>> users,
    String uid,
  ) {
    for (final user in users) {
      if (user['uid']?.toString() == uid) return user;
    }
    return null;
  }

  Map<String, dynamic>? _findLocalUserByUsername(
    List<Map<String, dynamic>> users,
    String username,
  ) {
    final cleanUsername = _normalizeUsername(username);
    for (final user in users) {
      if (_normalizeUsername(user['username']?.toString() ?? '') ==
          cleanUsername) {
        return user;
      }
    }
    return null;
  }

  AppUser _appUserFromLocalMap(Map<String, dynamic> map) {
    return AppUser.fromMap(map['uid']?.toString() ?? '', map);
  }

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  String _normalizeUsername(String username) {
    return _normalizeUsernameStatic(username);
  }

  void _validateUsername(String username) {
    final message = validateUsernameText(username);
    if (message != null) throw AuthServiceException(message);
  }

  String _internalEmailForUsername(String username) {
    final clean = _normalizeUsername(
      username,
    ).replaceAll(RegExp(r'[^a-z0-9._-]'), '');
    return '$clean@$_internalEmailDomain';
  }

  Future<String> _firebaseEmailForUsername(String username) async {
    final snapshot = await _users
        .where('username', isEqualTo: _normalizeUsername(username))
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return _internalEmailForUsername(username);
    }

    final email = snapshot.docs.first.data()['email']?.toString() ?? '';
    return email.trim().isEmpty ? _internalEmailForUsername(username) : email;
  }

  void _sortUsers(List<AppUser> users) {
    users.sort((a, b) {
      if (a.deleted != b.deleted) return a.deleted ? 1 : -1;
      if (a.active != b.active) return a.active ? -1 : 1;
      return a.displayLabel.toLowerCase().compareTo(
        b.displayLabel.toLowerCase(),
      );
    });
  }

  String _authMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Tên đăng nhập không hợp lệ.';
      case 'user-disabled':
        return 'Tài khoản này đã bị khóa.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Tên đăng nhập hoặc mật khẩu không đúng.';
      case 'email-already-in-use':
        return 'Tên đăng nhập này đã có tài khoản.';
      case 'weak-password':
        return 'Mật khẩu cần ít nhất 6 ký tự.';
      case 'operation-not-allowed':
        return 'Firebase chưa bật đăng nhập bằng Email/Password.';
      default:
        return e.message ?? 'Đăng nhập thất bại.';
    }
  }
}
