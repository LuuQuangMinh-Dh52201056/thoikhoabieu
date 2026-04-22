import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';
import '../models/app_user.dart';

class AuthServiceException implements Exception {
  final String message;

  const AuthServiceException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  final FirebaseAuth? _providedAuth;
  final FirebaseFirestore? _providedDb;

  AuthService({FirebaseAuth? auth, FirebaseFirestore? db})
    : _providedAuth = auth,
      _providedDb = db;

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
    if (!FirebaseEnv.isConfigured) return null;
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
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

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

  Future<void> signOut() {
    if (!FirebaseEnv.isConfigured) return Future.value();
    return _auth.signOut();
  }

  Future<List<AppUser>> getUsers() async {
    final profile = await currentProfile();
    if (profile?.isAdmin != true) {
      throw const AuthServiceException('Bạn không có quyền quản lý tài khoản.');
    }

    final snapshot = await _users.orderBy('displayName').get();
    final users = snapshot.docs
        .map((doc) => AppUser.fromMap(doc.id, doc.data()))
        .toList();
    users.sort((a, b) {
      if (a.deleted != b.deleted) return a.deleted ? 1 : -1;
      if (a.active != b.active) return a.active ? -1 : 1;
      return a.displayLabel.toLowerCase().compareTo(
        b.displayLabel.toLowerCase(),
      );
    });
    return users;
  }

  Future<AppUser> createUser({
    required String email,
    required String password,
    required String displayName,
    required String role,
  }) async {
    final admin = await currentProfile();
    if (admin == null || !admin.isAdmin) {
      throw const AuthServiceException('Chỉ admin mới được tạo tài khoản.');
    }

    final secondaryApp = await Firebase.initializeApp(
      name: 'create-user-${DateTime.now().millisecondsSinceEpoch}',
      options: Firebase.app().options,
    );
    final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

    User? createdUser;
    try {
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
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
        email: createdUser.email ?? email.trim(),
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
    final admin = await currentProfile();
    if (admin == null || !admin.isAdmin) {
      throw const AuthServiceException(
        'Chỉ admin mới được gửi đặt lại mật khẩu.',
      );
    }

    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> sendOwnPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  String _authMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Email không hợp lệ.';
      case 'user-disabled':
        return 'Tài khoản này đã bị khóa.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email hoặc mật khẩu không đúng.';
      case 'email-already-in-use':
        return 'Email này đã có tài khoản.';
      case 'weak-password':
        return 'Mật khẩu cần ít nhất 6 ký tự.';
      case 'operation-not-allowed':
        return 'Firebase chưa bật đăng nhập bằng Email/Password.';
      default:
        return e.message ?? 'Đăng nhập thất bại.';
    }
  }
}
