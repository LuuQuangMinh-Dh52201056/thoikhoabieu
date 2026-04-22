import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class FirebaseEnv {
  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const _messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const _storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );
  static const _localAdminUsername = String.fromEnvironment(
    'LOCAL_ADMIN_USERNAME',
  );
  static const _localAdminPassword = String.fromEnvironment(
    'LOCAL_ADMIN_PASSWORD',
  );

  static Map<String, String> _runtimeValues = const {};

  static String get apiKey => _value('FIREBASE_API_KEY', _apiKey);
  static String get appId => _value('FIREBASE_APP_ID', _appId);
  static String get messagingSenderId =>
      _value('FIREBASE_MESSAGING_SENDER_ID', _messagingSenderId);
  static String get projectId => _value('FIREBASE_PROJECT_ID', _projectId);
  static String get authDomain => _value('FIREBASE_AUTH_DOMAIN', _authDomain);
  static String get storageBucket =>
      _value('FIREBASE_STORAGE_BUCKET', _storageBucket);
  static String get localAdminUsername =>
      _value('LOCAL_ADMIN_USERNAME', _localAdminUsername);
  static String get localAdminPassword =>
      _value('LOCAL_ADMIN_PASSWORD', _localAdminPassword);

  static Future<void> load() async {
    try {
      final content = await rootBundle.loadString(
        'config/firebase_config.json',
      );
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) {
        _runtimeValues = decoded.map(
          (key, value) => MapEntry(key, value?.toString().trim() ?? ''),
        );
      }
    } catch (_) {
      _runtimeValues = const {};
    }
  }

  static bool get isConfigured {
    return apiKey.isNotEmpty &&
        appId.isNotEmpty &&
        messagingSenderId.isNotEmpty &&
        projectId.isNotEmpty;
  }

  static String _value(String key, String compileTimeValue) {
    if (compileTimeValue.isNotEmpty) return compileTimeValue;
    return _runtimeValues[key] ?? '';
  }
}

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (!FirebaseEnv.isConfigured) {
      throw StateError('Firebase has not been configured.');
    }

    if (kIsWeb) return web;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return web;
    }
  }

  static FirebaseOptions get web {
    return FirebaseOptions(
      apiKey: FirebaseEnv.apiKey,
      appId: FirebaseEnv.appId,
      messagingSenderId: FirebaseEnv.messagingSenderId,
      projectId: FirebaseEnv.projectId,
      authDomain: FirebaseEnv.authDomain.isEmpty
          ? '${FirebaseEnv.projectId}.firebaseapp.com'
          : FirebaseEnv.authDomain,
      storageBucket: FirebaseEnv.storageBucket.isEmpty
          ? '${FirebaseEnv.projectId}.appspot.com'
          : FirebaseEnv.storageBucket,
    );
  }
}
